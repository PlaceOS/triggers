require "../state"

module PlaceOS::Triggers
  class State::Comparison
    Log = ::Log.for(self)

    property left : Constant
    property compare : String
    property right : Constant

    def initialize(
      @state : State,
      @condition_key : String,
      @system_id : String,
      left : Model::Trigger::Conditions::Comparison::Value,
      @compare : String,
      right : Model::Trigger::Conditions::Comparison::Value
    )
      @left = self.class.parse_model_comparison(left)
      @right = self.class.parse_model_comparison(right)
    end

    def bind!(subscriptions) : Nil
      left.bind!(self, subscriptions, @system_id)
      right.bind!(self, subscriptions, @system_id)
      nil
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def compare!
      left_val = @left.value
      right_val = @right.value

      result = case compare
               when "equal"
                 left_val == right_val
               when "not_equal"
                 left_val != right_val
               when "greater_than"
                 left_val.as(Float64 | Int64) > right_val.as(Float64 | Int64)
               when "greater_than_or_equal"
                 left_val.as(Float64 | Int64) >= right_val.as(Float64 | Int64)
               when "less_than"
                 left_val.as(Float64 | Int64) < right_val.as(Float64 | Int64)
               when "less_than_or_equal"
                 left_val.as(Float64 | Int64) <= right_val.as(Float64 | Int64)
               when "and"
                 left_val != false && right_val != false && !left_val.nil? && !right_val.nil?
               when "or"
                 (left_val != false && !left_val.nil?) || (right_val != false && !right_val.nil?)
               when "exclusive_or"
                 if left_val != false && right_val != false && !left_val.nil? && !right_val.nil?
                   false
                 else
                   (left_val != false && !left_val.nil?) || (right_val != false && !right_val.nil?)
                 end
               else
                 false
               end

      Log.debug { {
        message:   "comparing #{left_val.inspect} #{compare} #{right_val.inspect} == #{result}",
        system_id: @system_id,
      } }

      @state.set_condition @condition_key, result
    rescue error
      @state.set_condition @condition_key, false
      @state.increment_comparison_error
      Log.warn(exception: error) { {
        message:   "comparing #{@left.value.inspect} #{@compare} #{@right.value.inspect}",
        system_id: @system_id,
      } }
    end

    def self.parse_model_comparison(value : Model::Trigger::Conditions::Comparison::Value)
      case value
      in Model::Trigger::Conditions::Comparison::Constant
        Constant.new(value)
      in Model::Trigger::Conditions::Comparison::StatusVariable
        Status.new(value)
      end
    end

    class Constant
      getter value : JSON::Any::Type

      def initialize(@value)
      end

      def bind!(comparison, subscriptions, system_id) : Nil
      end
    end

    class Status < Constant
      private getter status : Model::Trigger::Conditions::Comparison::StatusVariable

      def initialize(@status)
        super(nil)
      end

      def bind!(comparison, subscriptions, system_id) : Nil
        module_name, index = Driver::Proxy::RemoteDriver.get_parts(status[:mod])

        Log.context.set(system_id: system_id, module: module_name, index: index)

        Log.debug { {
          status:  status[:status],
          message: "subscribed to '#{status[:status]}'",
        } }

        subscriptions.subscribe(system_id, module_name, index, status[:status]) do |_, data|
          val = JSON.parse(data)

          Log.debug { {
            status:  status[:status],
            message: "received value for comparison: #{data}",
          } }

          # Grab the deeper key if specified
          final_index = status[:keys].size - 1
          status[:keys].each_with_index do |key, inner_index|
            break if val.raw.nil?

            next_val = val[key]?
            if next_val
              case next_val.raw
              when Hash
                val = next_val
              else
                if final_index == inner_index
                  val = next_val
                else
                  # There are more keys and we don't have a hash to go deeper
                  val = nil
                  break
                end
              end
            else
              val = nil
              break
            end
          end

          Log.debug { {
            status:  status[:status],
            message: "dug for #{status[:keys]} - got #{val.inspect}",
          } }

          # Update the value and re-compare
          if val
            @value = val.raw
          else
            @value = nil
          end

          comparison.compare!
        end
      end
    end
  end
end

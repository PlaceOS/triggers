module PlaceOS::Triggers::Api
  class Webhook < Application
    base "/api/triggers/v2/webhook"

    # =====================
    # Filters
    # =====================

    @[AC::Route::Filter(:before_action)]
    def find_hook(id : String, secret : String)
      # Find will raise a 404 (not found) if there is an error
      trig = Model::TriggerInstance.find!(id)

      # Determine the validity of loaded TriggerInstance
      if trig.enabled
        if trig.webhook_secret == secret
          @trigger = trig
        else
          message = "incorrect secret for trigger instance #{id}"
          Log.warn { {
            message:   message,
            instance:  id,
            trigger:   trig.trigger_id,
            system_id: trig.control_system_id,
          } }
          raise Error::NotFound.new(message)
        end
      else
        message = "webhook for disabled trigger instance #{id}"
        Log.warn { {
          message:   message,
          instance:  id,
          trigger:   trig.trigger_id,
          system_id: trig.control_system_id,
        } }
        raise Error::NotFound.new(message)
      end
    end

    getter! trigger : Model::TriggerInstance

    # =====================
    # Routes
    # =====================

    # Informs the service that a webhook has been performed
    # Return 204 if the state isn't loaded, 202 on success
    @[AC::Route::POST("/:id", status: {
      String => HTTP::Status::ACCEPTED,
      Nil    => HTTP::Status::NO_CONTENT,
    })]
    def create : String?
      trig = trigger
      trigger_id = trig.id
      if state = Triggers.mapping.state_for? trig
        Log.debug { {
          message:   "setting webhook condition for '#{state.trigger.name}'",
          instance:  trigger_id,
          trigger:   trig.trigger_id,
          system_id: trig.control_system_id,
        } }
        state.temporary_condition_met("webhook")
        ""
      else
        Log.warn { {
          message:   "trigger state not loaded",
          instance:  trigger_id,
          trigger:   trig.trigger_id,
          system_id: trig.control_system_id,
        } }
        nil
      end
    end
  end
end

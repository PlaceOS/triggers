require "./helper"

with_server do
  it "health checks" do
    result = curl("GET", "/api/triggers/v2/")
    result.status_code.should eq 200
  end

  it "should check version" do
    result = curl("GET", "/api/triggers/v2/version")
    result.status_code.should eq 200
    PlaceOS::Model::Version.from_json(result.body).service.should eq "triggers"
  end
end

defmodule NornsSdk.ClientTest do
  use ExUnit.Case, async: true

  alias NornsSdk.Client

  test "new/2 creates client with defaults" do
    client = Client.new("http://localhost:4000")
    assert client.base_url == "http://localhost:4000"
  end

  test "new/2 strips trailing slash" do
    client = Client.new("http://localhost:4000/")
    assert client.base_url == "http://localhost:4000"
  end

  test "new/2 accepts api_key" do
    client = Client.new("http://localhost:4000", api_key: "nrn_test")
    assert client.api_key == "nrn_test"
  end
end

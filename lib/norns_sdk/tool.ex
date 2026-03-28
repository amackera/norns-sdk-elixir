defmodule NornsSdk.Tool do
  @moduledoc """
  Defines a tool that an agent can call.

  ## Usage

      defmodule MyTools.SearchDocs do
        use NornsSdk.Tool,
          name: "search_docs",
          description: "Search product documentation",
          side_effect: false

        @impl true
        def input_schema do
          %{
            "type" => "object",
            "properties" => %{
              "query" => %{"type" => "string", "description" => "Search query"}
            },
            "required" => ["query"]
          }
        end

        @impl true
        def execute(%{"query" => query}) do
          results = MyApp.Docs.search(query)
          {:ok, results}
        end
      end
  """

  @callback input_schema() :: map()
  @callback execute(input :: map()) :: {:ok, String.t()} | {:error, String.t()}

  defmacro __using__(opts) do
    name = Keyword.fetch!(opts, :name)
    description = Keyword.fetch!(opts, :description)
    side_effect = Keyword.get(opts, :side_effect, false)

    quote do
      @behaviour NornsSdk.Tool

      def __tool_name__, do: unquote(name)
      def __tool_description__, do: unquote(description)
      def __tool_side_effect__, do: unquote(side_effect)

      def to_registration do
        %{
          "name" => __tool_name__(),
          "description" => __tool_description__(),
          "input_schema" => input_schema(),
          "side_effect" => __tool_side_effect__()
        }
      end
    end
  end
end

defmodule CryptoApp.Crypto do
  use Tesla

  @api_endpoint "https://api.binance.com/api/v3/ticker/price"
  @historical_data_endpoint "https://api.binance.com/api/v3/klines"
  @volume_endpoint "https://api.binance.com/api/v3/ticker/24hr"

  def get_usdt_pairs do
    case Tesla.get(@api_endpoint) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        body
        |> Jason.decode!()
        |> Enum.filter(&String.ends_with?(&1["symbol"], "USDT"))
        |> Enum.map(&%{"symbol" => &1["symbol"], "price" => &1["price"]})

      {:error, reason} ->
        IO.inspect(reason, label: "Failed to fetch crypto data")
        []
    end
  end

  def get_price(pair) do
    case Tesla.get("#{@api_endpoint}?symbol=#{pair}") do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        body
        |> Jason.decode!()
        |> Map.get("price")

      {:error, reason} ->
        IO.inspect(reason, label: "Failed to fetch price data")
        "N/A"
    end
  end

  def get_historical_data(pair, interval) do
    case Tesla.get("#{@historical_data_endpoint}?symbol=#{pair}&interval=#{interval}&limit=24") do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        body
        |> Jason.decode!()
        |> Enum.map(fn [timestamp, _open, _high, _low, close | _rest] ->
          %{
            time: DateTime.from_unix!(div(timestamp, 1000)),
            price: close
          }
        end)

      {:error, reason} ->
        []
    end
  end

  def get_popular_currencies(limit \\ 10) do
    case Tesla.get(@volume_endpoint) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        body
        |> Jason.decode!()
        |> Enum.sort_by(& &1["volume"], :desc)
        |> Enum.take(limit)
        |> Enum.map(&%{
          "symbol" => &1["symbol"],
          "price" => &1["lastPrice"],
          "volume" => &1["volume"],
          "price_change" => &1["priceChangePercent"]
        })

      {:error, reason} ->
        IO.inspect(reason, label: "Failed to fetch popular currencies")
        []
    end
  end

  def get_currency_info(pair) do
    case Tesla.get("#{@volume_endpoint}?symbol=#{pair}") do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        Jason.decode!(body)

      {:error, reason} ->
        IO.inspect(reason, label: "Failed to fetch currency info")
        %{}
    end
  end

  def search_currencies(query) do
    query_downcase = String.downcase(query)

    get_popular_currencies(1000)
    |> Enum.filter(fn currency ->
      symbol = String.downcase(currency["symbol"])
      String.contains?(symbol, query_downcase)
    end)
  end
end

defmodule CryptoAppWeb.CryptoLive do
  use Phoenix.LiveView

  alias CryptoApp.Crypto

  def mount(_params, _session, socket) do
    if connected?(socket), do: send(self(), :load_cryptos)

    :timer.send_interval(5000, self(), :update_data)

    {:ok,
     assign(socket,
       usdt_pairs: [],
       selected_pair: nil,
       current_price: nil,
       previous_price: nil,
       chart_data: [],
       selected_interval: "1h",
       position: nil,
       leverage: 1,
       entry_price: nil,
       quantity: 1,
       profit: 0,
       is_long: true,
       open_position: nil,
       arrow_direction: nil
     )}
  end

  def handle_info(:load_cryptos, socket) do
    usdt_pairs = Crypto.get_usdt_pairs()
    {:noreply, assign(socket, usdt_pairs: usdt_pairs, quantity: socket.assigns.quantity)}
  end

  def handle_info(:update_data, socket) do
    case socket.assigns.selected_pair do
      nil ->
        {:noreply, socket}
      pair ->
        new_price = Crypto.get_price(pair)
        chart_data = Crypto.get_historical_data(pair, socket.assigns.selected_interval)

        arrow_direction = if new_price > socket.assigns.current_price do
          "▲"
        else
          "▼"
        end

        profit = if socket.assigns.open_position do
          calculate_profit(
            new_price,
            socket.assigns.entry_price,
            socket.assigns.quantity,
            socket.assigns.leverage,
            socket.assigns.is_long
          )
        else
          0
        end

        {:noreply, socket
        |> assign(current_price: new_price, previous_price: socket.assigns.current_price, arrow_direction: arrow_direction, chart_data: chart_data, profit: profit, usdt_pairs: socket.assigns.usdt_pairs)
        |> push_event("update-chart", %{chart_data: chart_data, selected_pair: pair, arrow_direction: arrow_direction})}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-2xl mx-auto bg-white border border-gray-200 rounded-lg shadow-md">
      <h1 class="text-2xl font-semibold text-gray-900 mb-6">Select Cryptocurrency Pair (Crypto/USDT)</h1>

      <form phx-change="select_currency" class="mb-6">
    <div class="mb-4">
      <select name="currency_pair" class="block w-full p-2 border border-gray-300 rounded-md shadow-sm text-gray-900">
        <option value="">Select a pair</option>
        <%= for pair <- @usdt_pairs do %>
          <option value={pair["symbol"]} selected={@selected_pair == pair["symbol"]}><%= pair["symbol"] %></option>
        <% end %>
      </select>
    </div>
  </form>

  <form phx-change="select_interval" class="mb-6">
    <div class="mb-4">
      <select name="interval" class="block w-full p-2 border border-gray-300 rounded-md shadow-sm text-gray-900">
        <%= for {value, label} <- [{"1m", "1 Minute"}, {"3m", "3 Minutes"}, {"5m", "5 Minutes"},
                                   {"15m", "15 Minutes"}, {"30m", "30 Minutes"}, {"1h", "1 Hour"},
                                   {"4h", "4 Hours"}, {"1d", "1 Day"}, {"1w", "1 Week"}, {"1M", "1 Month"}] do %>
          <option value={value} selected={@selected_interval == value}><%= label %></option>
        <% end %>
      </select>
    </div>
  </form>

  <div class="mb-6">
  <div class="text-lg font-medium text-gray-800">
    <strong>Selected Pair:</strong> <%= @selected_pair %>
  </div>
  <div class="text-lg font-medium text-gray-800">
    <strong>Current Price:</strong>
    <span>
      <%= @current_price %> <%= @arrow_direction %>
    </span>
  </div>
</div>

      <form phx-submit="open_position" class="mb-6">
        <div class="mb-4">
          <label for="position" class="block text-sm font-medium text-gray-700">Position</label>
          <select name="position" id="position" class="block w-full p-2 border border-gray-300 rounded-md shadow-sm text-gray-900">
            <option value="long">Long</option>
            <option value="short">Short</option>
          </select>
        </div>

        <div class="mb-4">
          <label for="leverage" class="block text-sm font-medium text-gray-700">Leverage</label>
          <input type="number" name="leverage" id="leverage" value="1" class="block w-full p-2 border border-gray-300 rounded-md shadow-sm text-gray-900" min="1" max="100">
        </div>

        <div class="mb-4">
          <label for="quantity" class="block text-sm font-medium text-gray-700">Quantity</label>
          <input type="number" step="0.01" name="quantity" id="quantity" value={@quantity} class="block w-full p-2 border border-gray-300 rounded-md shadow-sm text-gray-900">
        </div>

        <button type="submit" class="w-full py-2 px-4 bg-blue-500 text-white rounded-md shadow-sm hover:bg-blue-600">Open Position</button>
      </form>

      <div class="mb-6">
        <div class="text-lg font-medium text-gray-800">
          <strong>Open Position:</strong> <%= if @open_position do %><%= if @is_long, do: "Long", else: "Short" %> @<%= @entry_price %> with <%= @leverage %>x Leverage<% else %> None <% end %>
        </div>
        <div class="text-lg font-medium text-gray-800">
          <strong>Profit:</strong> <%= @profit %>
        </div>
      </div>

      <div id="chart-container" phx-update="ignore">
        <div id="crypto-chart"></div>
      </div>

      <script>
        document.addEventListener("DOMContentLoaded", function() {
          var layout = {
            title: 'Cryptocurrency Price Over Time',
            xaxis: {
              title: 'Time'
            },
            yaxis: {
              title: 'Price'
            }
          };

          var data = [{
            x: [],
            y: [],
            type: 'scatter',
            mode: 'lines+markers',
            marker: {color: 'red'}
          }];

          Plotly.newPlot('crypto-chart', data, layout);

          window.updateChart = function(data, label) {
            var times = data.map(d => new Date(d.time).toLocaleString());
            var prices = data.map(d => parseFloat(d.price));

            Plotly.update('crypto-chart', {
              x: [times],
              y: [prices]
            }, {}, 0);

            Plotly.relayout('crypto-chart', {
              title: label + ' Price Over the Last Selected Interval'
            });
          }

          let chartData = <%= @chart_data |> Jason.encode!() %>;
          let selectedPair = '<%= @selected_pair %>';
          if (chartData.length > 0 && selectedPair) {
            updateChart(chartData, selectedPair);
          }
        });

        window.addEventListener("phx:update-chart", function(event) {
          updateChart(event.detail.chart_data, event.detail.selected_pair);
        });
      </script>
    </div>
    """
  end

  def calculate_profit(entry_price, current_price, quantity, leverage, is_long) do
    entry_price = String.to_float(entry_price)
    current_price = String.to_float(current_price)

    price_difference = if is_long do
      current_price - entry_price
    else
      entry_price - current_price
    end

    profit = price_difference * quantity * leverage
    profit
  end

  def handle_event("select_currency", %{"currency_pair" => pair}, socket) do
        if pair != "" do
      price = Crypto.get_price(pair)
      chart_data = Crypto.get_historical_data(pair, socket.assigns.selected_interval)

      {:noreply,
       socket
       |> assign(selected_pair: pair, current_price: price, chart_data: chart_data)
       |> push_event("update-chart", %{chart_data: chart_data, selected_pair: pair})}
    else
      {:noreply, socket |> assign(selected_pair: nil, current_price: nil, chart_data: [])}
    end
  end

  def handle_event("select_interval", %{"interval" => interval}, socket) do
    case socket.assigns.selected_pair do
      nil ->
        {:noreply, socket}

      pair ->
        chart_data = Crypto.get_historical_data(pair, interval)

        {:noreply,
         socket
         |> assign(selected_interval: interval, chart_data: chart_data)
         |> push_event("update-chart", %{chart_data: chart_data, selected_pair: pair})}
    end
  end

  def handle_event("open_position", %{"quantity" => quantity, "leverage" => leverage, "position" => position}, socket) do
    leverage = String.to_integer(leverage)

    quantity =
      case Float.parse(quantity) do
        {float, _} -> float
        :error -> String.to_integer(quantity) |> Kernel./(1.0)
      end

    is_long = position == "long"

    {:noreply, socket
    |> assign(
         leverage: leverage,
         quantity: quantity,
         is_long: is_long,
         entry_price: socket.assigns.current_price,
         open_position: true,
         profit: 0
       )}
  end
end

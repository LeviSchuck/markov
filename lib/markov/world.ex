defmodule Markov.World do
  require Ex2ms
  def start_link(name) do
    Agent.start_link(fn ->
      weights = :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true])
      edges = :ets.new(__MODULE__, [:bag, :public, read_concurrency: true, write_concurrency: true])
      {weights, edges}
    end, name: {:via, :gproc, {:n, :l, name}})
  end

  def whereis(name) do
    :gproc.whereis_name({:n, :l, name})
  end

  def get_table(name) do
    proc = whereis(name)
    if is_pid(proc) do
      Agent.get(proc, fn x -> x end)
    end
  end

  def digest({weights, edges}, text) do
    words = String.split(text, ~r/\s+/)
    case words do
      [""] -> nil
      [] -> nil
      _ ->
        Enum.each([1, 2, 3, 4, 5], fn chain ->
          exec_walk(fn k, v ->
            case k do
              {} -> :ok
              _ ->
                :ets.insert(edges, {k, v})
                :ets.update_counter(weights, k, 1, {1, 0})
                :ets.update_counter(weights, {k, v}, 1, {1, 0})
            end
          end, words, chain)
        end)
    end
  end

  def talk(table, chain) do
    key = List.to_tuple(List.duplicate(:init, chain))
    blah = fn n, k, lim ->
      if lim > 0 do
        case talk(table, chain, k) do
          {:halt, _} -> []
          {l, b} -> l ++ n.(n, b, lim - 1)
        end
      else
        []
      end
    end
    blah.(blah, key, 30) |> Enum.join(" ")
  end
  def talk({weights, edges}, _chain, key) do
    case :ets.lookup(weights, key) do
      [] -> :sad
      [{_, c}] ->
        choice = :rand.uniform(c)
        result = :ets.lookup(edges, key)
          |> Enum.reduce_while(choice, fn {_, edge}, count ->
          case :ets.lookup(weights, {key, edge}) do
            [] ->
              IO.puts("Whoah, did not find #{inspect {key, edge}}")
              {:cont, count}
            [{_, weight}] ->
              remaining = count - weight
              if remaining <= 0 do
                {:halt, edge}
              else
                {:cont, remaining}
              end
          end
        end)
        case result do
          x when is_number(x) ->
            IO.puts("Could not burn through counts")
            {:halt, key}
          x ->
            case elem(x, 0) do
              :init -> {[], x}
              :term -> {:halt, x}
              text when is_binary(text) -> {[text], x}
            end
        end
    end
  end


  def dummy({weights, edges}) do
    :ets.foldl(fn x, acc ->
      IO.puts(inspect(x))
      acc
    end, nil, weights)
    :ets.foldl(fn x, acc ->
      IO.puts(inspect(x))
      acc
    end, nil, edges)
  end

  def exec_walk(fun, list, chain) do
    exec_walk(fun, list, [], chain)
  end
  def exec_walk(fun, list, acc, chain) do
    case walk(list, acc, chain) do
      :EOS -> nil
      {:cont, rest, result} ->
        fun.(List.to_tuple(acc), List.to_tuple(result))
        exec_walk(fun, rest, result, chain)
    end
  end

  def walk([]          , []         , _), do: :EOS
  def walk([]          , [:term | _], _), do: :EOS
  def walk([]          , [_ | rest] , _), do: {:cont, [], rest ++ [:term]}
  def walk([elem | arr], [_ | rest] , _) do
    {:cont, arr, rest ++ [elem]}
  end
  def walk(arr         , _          , chain) do
    {:cont, arr, List.duplicate(:init, chain)}
  end

# Keys:
# * {start, next} -> weight
end

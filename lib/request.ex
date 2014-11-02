defmodule Request do

  def data(connection, loop \\ true, previous_bytes \\ []) do
    case :gen_tcp.recv(connection, 0) do
      {:ok, bytes} when loop == false -> {:ok, IO.iodata_to_binary(bytes)}
      {:ok, bytes} -> data(connection, true, [previous_bytes, bytes])
      {:error, :closed} -> {:ok, IO.iodata_to_binary(previous_bytes)}
    end
  end

  def header(connection) do
    {:ok, header} = data(connection, false) # Receive only once
    [basic_info | encoded_fields] = String.split(to_string(header), "\r\n")
    [method, url | _] = String.split(basic_info)

    fields = Enum.reduce(encoded_fields, %{}, fn(field, map) ->
      case field do
        "" -> map
        _ ->
        case String.split(field, ": ") do
          [key, value] -> Map.put(map, key, value)
          _ -> map
        end
      end
    end)


    Map.merge(
      %{:fields => fields, :method => method},
      case String.split(url, "?") do
        [path, query_params] -> %{:path => path, :get_params => parse_params(query_params)}
        [path] -> %{:path => path, :get_params => %{}}
      end
    )
  end
  @doc ~S"""
  Parses GET or POST parameters from a String into a Map\n
  Arrays can be denoted by adding '[]' to the end of the variable name

  ## Examples
      iex> Request.parse_params "a=0&b[]=1&b[]=2"
      %{"a" => "0", "b" => ["2", "1"]}
  """ 
  def parse_params(encoded_params) do
    key_value_pairs = String.split(encoded_params,"&")
    Enum.reduce(key_value_pairs, %{}, fn(key_value_pair, map) ->
      case String.split(key_value_pair, "=") do
        [key, value] ->
          # Arrays in params may be encoded as:
          # ?arr[]=1&arr[]=2&arr[]=3  ==  [1, 2, 3]
          case String.ends_with?(key, "[]") do
            true ->
              trimmed_key = String.replace(key, "[]", "")
              map = Map.put_new(map, trimmed_key, [])
              Map.put(map, trimmed_key, [value | map[trimmed_key]])
            _ ->
              Map.put(map, key, value)
          end
        [key] -> Map.put(map, key, true)
      end
    end)
  end
end
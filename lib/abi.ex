defmodule ABI do
  @moduledoc """
  Documentation for ABI, the function interface language for Solidity.
  Generally, the ABI describes how to take binary Ethereum and transform
  it to or from types that Solidity understands.
  """

  @doc """
  Encodes the given data into the function signature or tuple signature.

  In place of a signature, you can also pass one of the `ABI.FunctionSelector` structs returned from `parse_specification/1`.

  ## Examples

      iex> ABI.encode("baz(uint,address)", [50, <<1::160>> |> :binary.decode_unsigned])
      ...> |> Base.encode16(case: :lower)
      "a291add600000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"

      iex> ABI.encode("baz(uint8)", [9999])
      ** (RuntimeError) Data overflow encoding uint, data `9999` cannot fit in 8 bits

      iex> ABI.encode("(uint x, address y)", [{50, <<1::160>> |> :binary.decode_unsigned}])
      ...> |> Base.encode16(case: :lower)
      "00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"

      iex> ABI.encode("(string)", [{"Ether Token"}])
      ...> |> Base.encode16(case: :lower)
      "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000"

      iex> ABI.encode("(string)", [{String.duplicate("1234567890", 10)}])
      ...> |> Base.encode16(case: :lower)
      "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000643132333435363738393031323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839303132333435363738393000000000000000000000000000000000000000000000000000000000"

      iex> File.read!("priv/dog.abi.json")
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification
      ...> |> Enum.find(&(&1.function == "bark")) # bark(address,bool)
      ...> |> ABI.encode([<<1::160>> |> :binary.decode_unsigned, true])
      ...> |> Base.encode16(case: :lower)
      "b85d0bd200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"
  """
  def encode(function_signature, data) when is_binary(function_signature) do
    encode(ABI.Parser.parse!(function_signature), data)
  end

  def encode(%ABI.FunctionSelector{} = function_selector, data) do
    ABI.TypeEncoder.encode(data, function_selector)
  end

  @doc """
  Decodes the given data based on the function or tuple
  signature.

  In place of a signature, you can also pass one of the `ABI.FunctionSelector` structs returned from `parse_specification/1`.

  ## Examples

      iex> ABI.decode("baz(uint,address)", "00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      [50, <<1::160>>]

      iex> ABI.decode("(address[])", "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      [{[]}]

      iex> ABI.decode("(string)", "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      [{"Ether Token"}]

      iex> File.read!("priv/dog.abi.json")
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification
      ...> |> Enum.find(&(&1.function == "bark")) # bark(address,bool)
      ...> |> ABI.decode("00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      [<<1::160>>, true]
  """
  def decode(function_signature, data) when is_binary(function_signature) do
    decode(ABI.Parser.parse!(function_signature), data)
  end

  def decode(%ABI.FunctionSelector{} = function_selector, data) do
    ABI.TypeDecoder.decode(data, function_selector)
  end

  @doc """
  Parses the given ABI specification document into an array of `ABI.FunctionSelector`s.

  Non-function entries (e.g. constructors) in the ABI specification are skipped. Fallback function entries are accepted.

  This function can be used in combination with a JSON parser, e.g. [`Jason`](https://hex.pm/packages/jason), to parse ABI specification JSON files.

  ## Examples

      iex> File.read!("priv/dog.abi.json")
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{function: "bark", returns: nil, types: [:address, :bool]},
       %ABI.FunctionSelector{function: "rollover", returns: :bool, types: []}]

      iex> File.read!("priv/dog.abi.json")
      ...> |> Poison.decode!
      ...> |> ABI.parse_specification(bindings: true)
      [%ABI.FunctionSelector{function: "bark", returns: nil, types: [{:binding, :address, %{name: "at"}}, {:binding, :bool, %{name: "loudly", indexed: true}}]},
       %ABI.FunctionSelector{function: "rollover", returns: {:binding, :bool, %{name: "is_a_good_boy"}}, types: []}]

      iex> [%{
      ...>   "constant" => true,
      ...>   "inputs" => [
      ...>     %{"name" => "at", "type" => "address"},
      ...>     %{"name" => "loudly", "type" => "bool"}
      ...>   ],
      ...>   "name" => "bark",
      ...>   "outputs" => [],
      ...>   "payable" => false,
      ...>   "stateMutability" => "nonpayable",
      ...>   "type" => "function"
      ...> }]
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{function: "bark", returns: nil, types: [:address, :bool]}]

      iex> [%{
      ...>   "inputs" => [
      ...>      %{"name" => "_numProposals", "type" => "uint8"}
      ...>   ],
      ...>   "payable" => false,
      ...>   "stateMutability" => "nonpayable",
      ...>   "type" => "constructor"
      ...> }]
      ...> |> ABI.parse_specification
      []

      iex> ABI.decode("(string)", "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000643132333435363738393031323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839303132333435363738393000000000000000000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      [{String.duplicate("1234567890", 10)}]

      iex> [%{
      ...>   "payable" => false,
      ...>   "stateMutability" => "nonpayable",
      ...>   "type" => "fallback"
      ...> }]
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{function: nil, returns: nil, types: []}]
  """
  def parse_specification(doc, opts \\ []) do
    return_bindings? = Keyword.get(opts, :bindings, false)
    doc
    |> Enum.map(&ABI.FunctionSelector.parse_specification_item(&1, return_bindings?))
    |> Enum.filter(& &1)
  end
end

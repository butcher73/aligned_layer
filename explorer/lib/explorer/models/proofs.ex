defmodule Proofs do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "proofs" do
    field :batch_merkle_root, :string
    field :proof_hash, :binary

    timestamps()
  end

  @doc false
  def changeset(new_proof, updates) do
    new_proof
    |> cast(updates, [:batch_merkle_root, :proof_hash])
    |> validate_required([:batch_merkle_root, :proof_hash])
    |> validate_format(:batch_merkle_root, ~r/0x[a-fA-F0-9]{64}/)
  end

  def cast_to_proofs(%BatchDB{} = batch) do
    case batch.proof_hashes do
      nil -> %{}
      proof_hashes -> Enum.map(proof_hashes, fn proof_hash ->
        %{batch_merkle_root: batch.merkle_root, proof_hash: proof_hash, inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second), updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)}
      end)
    end
  end

  def get_proofs_from_batch(%{merkle_root: batch_merkle_root}) do
    query = from(p in Proofs,
    where: p.batch_merkle_root == ^batch_merkle_root,
    select: p)

    case Explorer.Repo.all(query) do
      nil ->
        nil
      [] ->
        nil
      result ->
        result
    end
  end

  def get_number_of_batches_containing_proof(proof_hash_hex) do
    proof_hash_hex = String.replace_prefix(proof_hash_hex, "0x", "")

    {:ok, proof_hash_binary} = Base.decode16(proof_hash_hex, case: :mixed)

    query = from p in Proofs,
      where: p.proof_hash == ^proof_hash_binary,
      select: %{
        count: count(p.batch_merkle_root, :distinct)
      }

    case Explorer.Repo.one(query) do
      %{count: count} -> count
      nil -> 0
    end
  end

  def get_batches_containing_proof(proof_hash_hex, page \\ 1, page_size \\ 10) do
    proof_hash_hex = String.replace_prefix(proof_hash_hex, "0x", "")

    {:ok, proof_hash_binary} = Base.decode16(proof_hash_hex, case: :mixed)

    offset = (page - 1) * page_size

    query = from(p in Proofs,
      where: p.proof_hash == ^proof_hash_binary,
      order_by: [desc: p.id],
      limit: ^page_size,
      offset: ^offset,
      distinct: p.batch_merkle_root,
      select: p.batch_merkle_root)

    case Explorer.Repo.all(query) do
      [] ->
        []
      results ->
        results
        |> case do
          [] -> []
          [root] -> [root]
          roots -> roots
        end
    end
  end

end

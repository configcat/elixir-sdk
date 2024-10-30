defmodule ConfigCat.Registry do
  @moduledoc false

  @spec via_tuple(module(), ConfigCat.instance_id()) :: {:via, module(), term()}
  def via_tuple(module, instance_id) do
    {:via, Registry, {instance(), {module, instance_id}}}
  end

  @spec via_tuple(module(), ConfigCat.instance_id(), term()) :: {:via, module(), term()}
  def via_tuple(module, instance_id, value) do
    {:via, Registry, {instance(), {module, instance_id}, value}}
  end

  @spec instance :: module()
  def instance do
    ProcessTree.get(:registry, default: __MODULE__)
  end
end

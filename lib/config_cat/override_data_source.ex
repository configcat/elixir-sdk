defprotocol ConfigCat.OverrideDataSource do
  @moduledoc """
  Data source for local overrides of feature flags and settings.

  With flag overrides you can overwrite the feature flags & settings downloaded
  from the ConfigCat CDN with local values. Moreover, you can specify how the
  overrides should apply over the downloaded values. See `t:behaviour/0`.
  """

  alias ConfigCat.Config

  @typedoc """
  Flag override behaviour.

  The following 3 behaviours are supported:

  - Local/Offline mode (`:local_only`): When evaluating values, the SDK will not
    use feature flags & settings from the ConfigCat CDN, but it will use all
    feature flags & settings that are loaded from local-override sources.

  - Local over remote (`:local_over_remote`): When evaluating values, the SDK
    will use all feature flags & settings that are downloaded from the ConfigCat
    CDN, plus all feature flags & settings that are loaded from local-override
    sources. If a feature flag or a setting is defined both in the downloaded
    and the local-override source then the local-override version will take
    precedence.

  - Remote over local (`:remote_over_local`): When evaluating values, the SDK
    will use all feature flags & settings that are downloaded from the ConfigCat
    CDN, plus all feature flags & settings that are loaded from local-override
    sources. If a feature flag or a setting is defined both in the downloaded
    and the local-override source then the downloaded version will take
    precedence.
  """
  @type behaviour :: :local_only | :local_over_remote | :remote_over_local

  @doc """
  Return the selected flag override behaviour.
  """
  @spec behaviour(data_source :: t) :: behaviour
  def behaviour(data_source)

  @doc """
  Return the local flag overrides from the data source.
  """
  @spec overrides(data_source :: t) :: Config.t()
  def overrides(data_source)
end

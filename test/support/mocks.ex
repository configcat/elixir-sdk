Mox.defmock(ConfigCat.MockAPI, for: HTTPoison.Base)
Mox.defmock(ConfigCat.MockCachePolicy, for: ConfigCat.CachePolicy.Behaviour)
Mox.defmock(ConfigCat.MockConfigCache, for: ConfigCat.ConfigCache)
Mox.defmock(ConfigCat.MockFetcher, for: ConfigCat.ConfigFetcher)

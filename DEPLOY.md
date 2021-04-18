# Steps to deploy
## Preparation
1. Install dependencies
   ```bash
   mix local.rebar --force
   mix local.hex --force
   mix deps.get
   ```
1. Run tests
   ```bash
   mix coveralls.json
   ```
2. Increase the project version in `mix.exs`.
4. Commit & Push
## Publish
Use the **same version** for the git tag as in `mix.exs`.
- Via git tag
    1. Create a new version tag.
       ```bash
       git tag v[MAJOR].[MINOR].[PATCH]
       ```
       > Example: `git tag v1.0.1`
    2. Push the tag.
       ```bash
       git push origin --tags
       ```
- Via Github release 

  Create a new [Github release](https://github.com/configcat/elixir-sdk/releases) with a new version tag and release notes.

## Elixir Package
Make sure the new version is available on [hex.pm](https://hex.pm/packages/configcat).

## Update samples
Update and test sample apps with the new SDK version.

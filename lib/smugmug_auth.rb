class SmugmugAuth < Struct.new(:api_key, :api_secret, :api_access_token, :api_access_token_secret)
  def self.from_env(env)
    SmugmugAuth.new(
      env.fetch("API_KEY"),
      env.fetch("API_SECRET"),
      env.fetch("API_ACCESS_TOKEN"),
      env.fetch("API_ACCESS_TOKEN_SECRET")
    )
  end
end

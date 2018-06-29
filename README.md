# Rifle

Rifle is a wrapper over [Gun](https://github.com/ninenines/gun). Rifle also provides pooling for Gun and reuses connections. Currently *WIP*

** TODO **

[X] - HTTP 1.1 & HTTP 2 support
[ ] - Websockets support
[ ] - Better Documentation

## Usage

In `Rifle`, you need to define a service(a domain and port to connect to). Then Rifle spawns a pool of Gun connections and spreads the requests on the pool of connections. Requests can be made on a service or pool.

To create a pool, you can add this line to your supervisor.

`{Rifle, %{name: :httpbin, domain: "httpbin.org", port: 443, pool_size: 10}}`

#### Options can contain:

- `name` - This needs to be the name of the pool or service. Needs to be unique.
- `domain` - Domain of the service
- `port` - Port it needs to connect to. If `443` is provided, it will automatically use TLS.
- `pool_size` - Number of `Gun` connections to create.

Adding this line will create supervisor with pool of connections.

#### For making requests:

`Rifle.request(service_name,  method, path, body, headers \\ [], req_opts \\ %{})`

- `service_name` is the name of the pool.
- `path` is the url path without the domain.
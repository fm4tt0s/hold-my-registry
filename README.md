# hold-my-registry

##Purpose

Generates client and server self-signed certificates used to enable HTTPS remote authentication to a Docker registry/daemon.

##References

http://docs.docker.com/articles/https/
https://docs.docker.com/registry/deploying/

##Requirements

	OpenSSL

## Remarks
This will generate a set of files that matters to registry and node machines. 
Registry box will use server certs, whereas node needs only the client certificate - usually placed on
/etc/docker/certs.d/[registry_url]/ca.crt

## How to
Clone => Execute => Secure the registry => Enable the nodes => Grab a beer!

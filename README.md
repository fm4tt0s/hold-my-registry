# hold-my-registry
> Secure your private Docker registry

Generates client and server self-signed certificates used to enable HTTPS remote authentication to a Docker registry/daemon.

## References

http://docs.docker.com/articles/https/

https://docs.docker.com/registry/deploying/

## Requirements

    OpenSSL

## Remarks

This will generate a set of files that matters to registry and node machines on a folder - as of ./output.$$ - where $$ is the PID of current run. Registry box will use server certs, whereas node needs only the client certificate - usually placed on:

    /etc/docker/certs.d/[registry_url]/ca.crt

## How To

Clone => Execute => Secure the registry => Enable the nodes => Grab a beer!

You will end up with three files that really matters to your secure registry bootstrap - on ./output.$$:

* CERTIFICATE.pem (docker env REGISTRY_HTTP_TLS_CERTIFICATE)
    * The server registry. 
* KEY.pem (docker env REGISTRY_HTTP_TLS_KEY)
    * The server private key.
* CLIENTCA.crt (docker env REGISTRY_HTTP_TLS_CLIENTCAS_0)
    * The client CA: That's the node ca.crt you need to place on /etc/docker/certs.d/[registry_url]/ca.crt at whichever box that is going to pull/push from this registry
* runtime files
    * other files used during runtime: ca-key.pem, ca.srl, client.csr, extfile.cnf, password.file, server-cert.pem, server-key.pem, server.csr. These files are not really important to you, you can keep them if you're too paranoic to trash them or, shove it all into registry /certs - wont make any harm.

## Docker Registry

Once you got the certificate files, copy it all to the volume mapped to container registry /certs folder and run your secure registry as:

    docker run -d \
    --env REGISTRY_HTTP_TLS_CERTIFICATE=/certs/cert.pem \
    --env REGISTRY_HTTP_TLS_KEY=/certs/key.pem \
    --env REGISTRY_HTTP_TLS_CLIENTCAS_0=/certs/ca.pem \
    --restart=always \
    --name registry-local \
    -p 5000:5000 \
    --volume "$(pwd)"/certs:/certs \
    --volume "$(pwd)"/registry:/var/lib/registry \
    registry:2

## Live
    $ ./hold-my-registry.sh 
    Certificate should be valid for N days (default, 730): 
    CA Common Name: (ex, ACME - default, *) 
    Registry Server Common Name: (ex, host123.acme.corp.com - default, *) 
    Registry Server IP: (ex, 1.2.3.4 - default, 0.0.0.0) 
    
    Generating RSA private key, 2048 bit long modulus
    ........................................................+++
    ........................................+++
    e is 65537 (0x10001)
    Generating RSA private key, 2048 bit long modulus
    .................................+++
    .................+++
    e is 65537 (0x10001)
    Signature ok
    subject=/CN=*
    Getting CA Private Key
    Generating RSA private key, 2048 bit long modulus
    ...................+++
    ............................................................+++
    e is 65537 (0x10001)
    Signature ok
    subject=/CN=*
    Getting CA Private Key
    writing RSA key
    writing RSA key

    Done! Your files are under /tmp/output.33730

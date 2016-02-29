- Feature Name: Multiple resources offered by Service Endpoint(s)
- Start Date: 2016-02-29

# Summary
[summary]: #summary

This document describes a model of using GOCDB to describe multiple resources offered by a single "Service Endpoint" or multiple "Service Endpoints" of the same "Service Type" running in parallel. NCG should be able to handle such use cases in order to correctly assign nagios checks for each endpoint. A "Service Endpoint" is a single entity formed by a hostname, a hosted service (Service Type) and a URL.


# Motivation
[motivation]: #motivation

GOCDB is the service registry used in EUDAT which can hold information about the services provided by an infrastructure. GOCDB supports: 

* A "Service Type" which is a technology used to provide a service. Each service endpoint in GOCDB is associated with a service type. Service types are pieces of software while service endpoints are a particular instance of that software running in a certain context. 

* A "Service Endpoint" which is a single entity formed by a hostname, a hosted service (Service Type) and a URL. As a machine can host many services, there can be many service endpoints per machine.

### Multiple resources offered by a single "Service Endpoint"

In the EUDAT CDI there are several cases in which an instance of a specific Service Endpoint can provide  different resources to different user communities/projects. An example of such a case is a Service Endpoint of Service Type 'b2handle.handle.api' that runs on 'epic.grnet.gr'. This Service Endpoint hosts multiple prefixes, which can be used by different users/communities. In this example the prefixes are the actual resources used by the end users.

In order to be able to monitor the service from the point of view of the users/communities, we need to be able the check the status, availability and reliability of the actual resources that are used by the users/communities. So, in the previous example, we need to be able to monitor the status, availability and reliability of the Service Endpoint of Service Type 'b2handle.handle.api', which run on the host 'epic.grnet.gr' for the specific prefix(es) that are used by the users/communities.

Currently in the GOCDB we are modelling resources up to the level of a Service Endpoint. In this document we propose an approach for modelling finer grained resources, like the prefixes that were described in the previous paragraph. The proposed approach relies on functionality that is already available in the GOCDB, but requires us to extend the information that we record in the GOCDB and to perform the appropriate modifications to the ARGO NCG component that is responsible for the generation of the Nagios configuration in order to be able to understand resources at a lower level than a Service Endpoint.

### Multiple "Service Endpoints" of the same "Service Type" running in parallel

In the current implementations of the GOCDB and ARGO data models in EUDAT, there is the assumption that there can be only 1 instance of Service Type running on a given host. This effectively means that there is the assumption that a host can have multiple Service Endpoints, but each Service Endpoint MUST be of different Service Type. Although this is a safe assumption to make in most cases, there are cases in which this assumption does not apply.

For example on the host 'epic.grnet.gr' there are 2 running instances of Service Type 'b2safe.handle.api'. Each of these instances is bind on different ports and serves a different set of prefixes. In order to be able to monitor these two instances of the same Service Type, running on the same host, we need to be able to properly model them in the GOCDB and to modify the ARGO NCG component to be able to generate the proper Nagios configuration.

The approach described in this document relies on functionality that is already available in the GOCDB, but requires us to extend the information that we record in the GOCDB and to perform the appropriate modifications to the ARGO NCG component that is responsible for the generation of the Nagios configuration.


# Detailed design
[design]: #detailed-design

## GOCDB
In EUDAT GOCDB we use the following model:
* Service Endpoints are the combination of a hostname and a Service Type
* Service Endpoints can be grouped together in Service Groups to model an EUDAT Service that is provided to a specific community (e.g. all the Service Points of the B2Handle EUDAT Service that have been assigned to Community X)

The solution proposed is to remove the artificial restriction to have unique Service Endpoints (unique tuples of Service Endpoint and hostname) and to utilise the GOCDB extensions to include richer information where needed. From the point of view of the monitoring service a resource will now be identified as the triplet: Hostname, Service Type, URL. This solution uses existing GOCDB features and requires only the input of extra data in the GOCDB.

Below follows the XML structure and the particular information for a service endpoint entry in GOCDB. Notice that in case of epic.grnet.gr there are two separate GOCDB entries with different IDs in order to be possible for us to retrieve the appropriate URL for each case.

ID | Hostname | Service Type | URL 
---|----------|--------------|-----
25F8|epic.grnet.gr|b2handle.handle.api|https://epic.grnet.gr:8181/api/v2/handles/11239
34JK|epic.grnet.gr|b2handle.handle.api|https://epic.grnet.gr:6767/api/v2/handles/11500
45V3|epic.grnet.gr|b2handle.handle.resolve|https://epic.grnet.gr
56GL|epic.rzg.mpg.de|b2handle.handle.api|https://epic.rzg.mpg.de/epic_v2/34155

We have to mention here that Urls may not be accurate because we are using demo data:

Calling the `get_service_endpoint` method on the GOCDB API we would get:
```
<SERVICE_ENDPOINT PRIMARY_KEY="25F8">
  <PRIMARY_KEY>25F8</PRIMARY_KEY>
  <HOSTNAME>epic.grnet.gr</HOSTNAME>
  <GOCDB_PORTAL_URL>
    https://creg.eudat.eu/view_portal/index.php?Page_Type=Service&id=384
  </GOCDB_PORTAL_URL>
  <HOSTDN>
    /C=GR/ST=Attica/L=Athens/O=Greek Research and Technology Network/CN=epic.grnet.gr
  </HOSTDN>
  <BETA>N</BETA>
  <SERVICE_TYPE>b2handle.handle.api</SERVICE_TYPE>
  <HOST_IP>62.217.127.244</HOST_IP>
  <HOST_IPV6>2001:648:2ffc:121:dcdb:eeff:fed6:ba9e/64</HOST_IPV6>
  <CORE/>
  <IN_PRODUCTION>Y</IN_PRODUCTION>
  <NODE_MONITORED>Y</NODE_MONITORED>
  <SITENAME>GRNET</SITENAME>
  <COUNTRY_NAME>Greece</COUNTRY_NAME>
  <COUNTRY_CODE>GR</COUNTRY_CODE>
  <ROC_NAME>EUDAT_REGISTRY</ROC_NAME>
  <URL>https://epic.grnet.gr:8181/api/v2/handles/11239</URL>
  <ENDPOINTS/>
  <EXTENSIONS>
    <EXTENSION>
      <LOCAL_ID>1</LOCAL_ID>
      <KEY>username</KEY>
      <VALUE>user</VALUE>
    </EXTENSION>
    <EXTENSION>
      <LOCAL_ID>2</LOCAL_ID>
      <KEY>epic_version</KEY>
      <VALUE>2.0</VALUE>
    </EXTENSION>
    <EXTENSION>
      <LOCAL_ID>3</LOCAL_ID>
      <KEY>handle_version</KEY>
      <VALUE>7.2.3</VALUE>
    </EXTENSION>
  </EXTENSIONS>
</SERVICE_ENDPOINT>

<SERVICE_ENDPOINT PRIMARY_KEY="34JK">
  <PRIMARY_KEY>34JK</PRIMARY_KEY>
  <HOSTNAME>epic.grnet.gr</HOSTNAME>
  <GOCDB_PORTAL_URL>
    https://creg.eudat.eu/view_portal/index.php?Page_Type=Service&id=384
  </GOCDB_PORTAL_URL>
  <BETA>N</BETA>
  <SERVICE_TYPE>b2handle.handle.api</SERVICE_TYPE>
  <HOST_IP>62.217.127.244</HOST_IP>
  <HOST_IPV6>2001:648:2ffc:121:dcdb:eeff:fed6:ba9e/64</HOST_IPV6>
  <CORE/>
  <IN_PRODUCTION>Y</IN_PRODUCTION>
  <NODE_MONITORED>Y</NODE_MONITORED>
  <SITENAME>GRNET</SITENAME>
  <COUNTRY_NAME>Greece</COUNTRY_NAME>
  <COUNTRY_CODE>GR</COUNTRY_CODE>
  <ROC_NAME>EUDAT_REGISTRY</ROC_NAME>
  <URL>https://epic.grnet.gr:6767/api/v2/handles/11500</URL>
  <ENDPOINTS/>
  <EXTENSIONS/>
</SERVICE_ENDPOINT>

<SERVICE_ENDPOINT PRIMARY_KEY="45V3">
  <PRIMARY_KEY>45V3</PRIMARY_KEY>
  <HOSTNAME>epic.grnet.gr</HOSTNAME>
  <GOCDB_PORTAL_URL>
    https://creg.eudat.eu/view_portal/index.php?Page_Type=Service&id=384
  </GOCDB_PORTAL_URL>
  <BETA>N</BETA>
  <SERVICE_TYPE>b2handle.handle.resolver</SERVICE_TYPE>
  <HOST_IP>62.217.127.244</HOST_IP>
  <CORE/>
  <IN_PRODUCTION>Y</IN_PRODUCTION>
  <NODE_MONITORED>Y</NODE_MONITORED>
  <SITENAME>GRNET</SITENAME>
  <COUNTRY_NAME>Greece</COUNTRY_NAME>
  <COUNTRY_CODE>GR</COUNTRY_CODE>
  <ROC_NAME>EUDAT_REGISTRY</ROC_NAME>
  <URL>https://epic.grnet.gr</URL>
  <ENDPOINTS/>
  <EXTENSIONS/>
</SERVICE_ENDPOINT>

<SERVICE_ENDPOINT PRIMARY_KEY="56GL">
  <PRIMARY_KEY>56GL</PRIMARY_KEY> 
  <GOCDB_PORTAL_URL>
    https://creg.eudat.eu/view_portal/index.php?Page_Type=Service&id=5
  </GOCDB_PORTAL_URL>
  <BETA>N</BETA>
  <SERVICE_TYPE>b2handle.handle.api</SERVICE_TYPE>
  <HOST_IP>130.183.206.85</HOST_IP>
  <CORE/>
  <IN_PRODUCTION>Y</IN_PRODUCTION>
  <NODE_MONITORED>Y</NODE_MONITORED>
  <SITENAME>MPCDF</SITENAME>
  <COUNTRY_NAME>Germany</COUNTRY_NAME>
  <COUNTRY_CODE>DE</COUNTRY_CODE>
  <ROC_NAME>EUDAT_REGISTRY</ROC_NAME>
  <URL>https://epic.rzg.mpg.de/epic_v2/34155</URL>
  <ENDPOINTS/>
  <EXTENSIONS/>
</SERVICE_ENDPOINT>

```

We should mention in that point that GOCDB allows each service endpoint to be assigned under one or more service groups.
It is also exposes information about service groups via the `get_service_group` API call. Since we have a separate entry for each service endpoint we can easily determine in which service groups it belongs to by looking the service endpoint ID. 

## NCG

ARGO NCG is the connector of the ARGO Monitor Engine for the GOCDB. ARGO NCG expects to retrieve from the GOCDB Hostname, Service Endpoint tuples, which are unique. The following example is a representation of the structure we are going to use to store the information we gather from the GOCDB for each service endpoint.

### Below is a perl hash that represents the proposed data model:

```
'epic.grnet.gr' => {
  'HOSTNAME' => 'epic.grnet.gr',
  'SERVICES' => {
    'b2handle.handle.api' => {
      'ID' => {
        '25F8' => {
          'ATTRIBUTES' => {
            'b2handle.handle.api_URL' => {
              'VALUE' => 'https://epic.grnet.gr:8181/api/v2/handles/11239'
            },
            'b2handle.handle.api_HOSTDN' => {
              'VALUE' => 'CERTIFICATE_DN'
            },
            'b2handle.handle.api_USERNAME' => {
              'VALUE' => 'user'
            },
            'b2handle.handle.api_VERSION' => {
              'VALUE' => '2.3'
            }
          }
        },
        '34JK' => {
          'ATTRIBUTES' => {
            'b2handle.handle.api_URL' => {
              'VALUE' => 'https://epic.grnet.gr:6767/api/v2/handles/11500'
            }
          }
        }
      }
    },
    'b2handle.handle.resolver' => {
      'ID' => {
        '45V3' => {
          'ATTRIBUTES' => {
            'b2handle.handle.resolver_URL' => {
              'VALUE' => 'https://epic.grnet.gr'
            },
            'b2handle.handle.resolver_USERNAME' => {
              'VALUE' => 'user'
            },
            'b2handle.handle.resolver_PREFIX' => {
              'VALUE' => '11239'
            },
            'b2handle.handle.resolver_SUFFIX' => {
              'VALUE' => 'MY_HANDLE'
            },
            'b2handle.handle.resolver_VERSION' => {
              'VALUE' => '8.1'
            }
          }
        }
      },
      'ADDRESS' => '62.217.127.244'
    }
  }
}
'epic.rzg.mpg.de' => {
  'HOSTNAME' => 'epic.rzg.mpg.de',
  'SERVICES' => {
    'b2handle.handle.api' => {
      'ID' => {
        '56GL' => {
          'ATTRIBUTES' => {
            'b2handle.handle.api_URL' => {
              'VALUE' => 'https://epic.rzg.mpg.de/epic_v2/34155'
            },
            'b2handle.handle.api_USERNAME' => {
              'VALUE' => 'user'
            },
            'b2handle.handle.api_VERSION' => {
              'VALUE' => '2.3'
            }
          }
        }
      }
    }
  },
  'ADDRESS' => '130.183.206.85'
}

```
## Nagios Configuration

The service_type ID can be used also in the Nagios service configurations (as a unique identifier in service_description) in order to distinguish multiple same service checks for a specific host. E.g:

```
define service{
        [...]
        host_name             epic.grnet.gr
        servicegroups         local, SITE_GRNET_b2handle.handle.api, SERVICE_b2handle.handle.api
        service_description   eu.eudat.b2handle.handle.api-API_check-25F8 
        check_command         check_epic_api.py --url https://epic.grnet.gr:8181/api/v2/handles/11239
        _service_uri          epic.grnet.gr
        _metric_name          eu.eudat.b2handle.handle.api-API_check-25F8
        _service_flavour      b2handle.handle.api
        [...]
}
define service{
        [...]
        host_name             epic.grnet.gr
        servicegroups         local, SITE_GRNET_b2handle.handle.api, SERVICE_b2handle.handle.api
        service_description   eu.eudat.b2handle.handle.api-API_check-34JK
        check_command         check_epic_api  --url https://epic.grnet.gr:6767/api/v2/handles/11500
        _service_uri          epic.grnet.gr
        _metric_name          eu.eudat.b2handle.handle.api-API_check-34JK
        _service_flavour      b2handle.handle.api
        [...]
}
```

In the example above we have two same service_endpoints (host/service_type) that we want to monitor by using one specific check with different parameters. In order to prevent Nagios handle this as a duplicate definition we include the ID in the `service_description` variable. The ID refers to the GOCDB entry with the specific parameter eg. assuming that we follow the XML example we gave a few lines above the ID in the first definition would be 25F8 whereas the second one would be 34JK.

###### Note:

For backwards compatibility we follow the naming convention `serviceType_PARAMETER-NAME` to store the GOCDB attributes (eg. `b2handle.handle.api_URL` , `b2handle.handle.api_HOSTDN` ). However this is subject to change in future releases.

# Drawbacks
[drawbacks]: #drawbacks

Multiple GOCDB entries in order to support complex scenarios. Might be difficult to maintain.


# Alternatives
[alternatives]: #alternatives

###### Use GOCDB's sub-endpoints feature per service endpoint.

Disadvantages:

* The way in which ncg parses the URL attribute is not sufficient. With the current implementation if there are more than one URL values (including the URL from "Grid Information" section) only the last one will be stored.
* Service groups can't be assigned per sub-endpoint.
* Difficult to distinguish metrics per service endpoint when there are also sub-endpoints with service types that are different from the parent entry. This has to do with the way we assign metrics to service types in POEM.


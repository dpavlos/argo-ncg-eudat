#!/usr/bin/perl -w
#
# Nagios configuration generator (WLCG probe based)
# Copyright (c) 2007 Emir Imamagic
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package NCG::SiteInfo::GOCDB;

use NCG::SiteInfo;
use strict;
use LWP::UserAgent;
use XML::DOM;
use vars qw(@ISA);

@ISA=("NCG::SiteInfo");

my $GOCDB_GET_METHOD = "/public/?method=get_service_endpoint";

sub new {
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my $self =  $class->SUPER::new(@_);

    if (! exists $self->{NODE_MONITORED}) {
        $self->{NODE_MONITORED} = 'Y';
    }

    #if (! exists $self->{PRODUCTION}) {
    #    $self->{PRODUCTION} = 'Y';
    #}
    
    if ($self->{SCOPE} && $self->{SCOPE} !~ /Local/) {
        $self->error("Incorrect SCOPE value, acceptable values are: Local.");
        return;
    }

    $self->{TIMEOUT} = $self->{DEFAULT_HTTP_TIMEOUT} unless ($self->{TIMEOUT});

    $self;
}

sub getData {
    my $self = shift;
    my $sitename = shift || $self->{SITENAME};

    my $ua = LWP::UserAgent->new(timeout=>$self->{TIMEOUT}, env_proxy=>1);
    $ua->agent("NCG::SiteInfo::GOCDB");
    
    if (!$self->{GOCDB_ROOT_URL}) {
        $self->error("Unable to fetch service endpoints from GOCDB. Please define a valid GOCDB url under SiteInfo section of NCG's configuration file.");
        return 0;
    }
    my $url = $self->{GOCDB_ROOT_URL} . $GOCDB_GET_METHOD . '&sitename=' . $sitename;
    if ($self->{NODE_MONITORED}) {
        $url .= '&monitored=' . $self->{NODE_MONITORED};
    }
    if ($self->{SCOPE}) {
        $url .= '&scope=' . $self->{SCOPE};
    }

    my $req = HTTP::Request->new(GET => $url);
    my $res = $self->safeHTTPSCall($ua,$req);
    if (!$res->is_success) {
        $self->error("Could not get results from GOCDB: ".$res->status_line);
        return 0;
    }

    my $parser = new XML::DOM::Parser(ErrorContext => 2);
    my $doc;
    eval {
        $doc = $parser->parse($res->content);
    };
    if ($@) {
        $self->error("Error parsing XML response: ".$@);
        return;
    }

    foreach my $site ($doc->getElementsByTagName("SERVICE_ENDPOINT")) {
        my $elem;
        my $subelem;
        my $hostname;

        if ($self->{PRODUCTION}) {
            my $prod;
            foreach $elem ($site->getElementsByTagName("IN_PRODUCTION")) {
                my $value = $elem->getFirstChild->getNodeValue();
                if ($value) {
                    $prod = $value;
                }
            }
            if ($prod && $prod ne $self->{PRODUCTION}) {
                next;
            }
        }

        foreach $elem ($site->getElementsByTagName("HOSTNAME")) {
            my $value = $elem->getFirstChild->getNodeValue();
            if ($value) {
                $hostname = $value;
                $self->{SITEDB}->addHost($hostname);
            }
        }

        if ($hostname) {
            my $serviceType;
            foreach $elem ($site->getElementsByTagName("SERVICE_TYPE")) {
                my $value = $elem->getFirstChild->getNodeValue();
                if ($value) {
                    $self->{SITEDB}->addService($hostname, $value);

                    $self->{SITEDB}->siteLDAP($hostname) if ($value eq 'Site-BDII');

                    $serviceType = $value;
                }
            }
            if ($serviceType) {
                foreach $elem ($site->getElementsByTagName("HOSTDN")) {
                    my $child = $elem->getFirstChild;
                    if ($child) {
                        my $value = $child->getNodeValue();
                        if ($value) {
                            $self->{SITEDB}->hostAttribute($hostname, $serviceType."_HOSTDN", $value);
                        }
                    }
                }
                foreach $elem ($site->getElementsByTagName("URL")) {
                    my $child = $elem->getFirstChild;
                    if ($child) {
                        my $value = $child->getNodeValue();
                        if ($value) {
                            $self->{SITEDB}->hostAttribute($hostname, $serviceType."_URL", $value);
                        }
                    }
                }
                foreach $elem ($site->getElementsByTagName("EXTENSIONS")) {
                    foreach $subelem ($elem->getElementsByTagName("EXTENSION")) {
                        my $k = $subelem->getElementsByTagName("KEY");
                        my $k_item = $k->item(0);
                        my $k_child = $k_item->getFirstChild;
                        my $k_value = $k_child->getNodeValue();
                        my $v = $subelem->getElementsByTagName("VALUE");
                        my $v_item = $v->item(0);
                        my $v_child = $v_item->getFirstChild;
                        my $v_value = $v_child->getNodeValue();
                        if ($k_value) {
                            $self->{SITEDB}->hostAttribute($hostname, $serviceType."_".uc$k_value, $v_value);
                            print "Found extension: $serviceType\.$k_value for host: $hostname \n";
                        }
                    }
                }
            }
        }

        if (!$self->{SITEDB}->siteCountry()) {
            foreach $elem ($site->getElementsByTagName("COUNTRY_NAME")) {
                my $value = $elem->getFirstChild->getNodeValue();
                if ($value) {
                    $self->{SITEDB}->siteCountry($value);
                }
            }
        }
    }

    $doc->dispose;

    1;
}

=head1 NAME

NCG::SiteInfo::GOCDB

=head1 DESCRIPTION

The NCG::SiteInfo::GOCDB module extends NCG::SiteInfo module. Module
extracts site information from GOCDB.

=head1 SYNOPSIS

  use NCG::SiteInfo::GOCDB;

  my $siteInfo = NCG::SiteInfo::GOCDB->new();

  $siteInfo->getData();

=cut

=head1 METHODS

=over

=item C<new>

  my $siteInfo = NCG::SiteInfo::GOCDB->new($options);

Creates new NCG::SiteInfo::GOCDB instance. Argument $options is hash reference that
can contains following elements:
  GOCDB_ROOT_URL - root URL used for GOCDB query interface
                 - only if GOCDB_ACCESS_TYPE is xml

  NODE_MONITORED - is node monitored (for possible values see GOCDB documentation)
                 - default: Y

  PRODUCTION - is node in production (for possible values see GOCDB documentation)
             - default: Y

  SCOPE - scope of services (for possible values see GOCDB documentation)
        - default: undefined
             
  TIMEOUT - HTTP timeout,
  (default: DEFAULT_HTTP_TIMEOUT inherited from NCG)

=back

=head1 SEE ALSO

NCG::SiteInfo

=cut

1;

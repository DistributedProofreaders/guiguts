# ======================================================================
#
# Copyright (C) 2000-2001 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: Lite.pm,v 1.6 2001/09/03 03:58:30 paulk Exp $
#
# ======================================================================

package UDDI::Lite;

use 5.004;
use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%s", map {s/_//g; $_} q$Name: release-0_55-public $ =~ /-(\d+)_([\d_]+)/);

use SOAP::Lite;

# ======================================================================

package UDDI::SOM;

use vars qw(@ISA);
@ISA = qw(SOAP::SOM);

sub result { # result should point to immediate child of Body
  my $self = shift;
  my $result = '/Envelope/Body/[1]'; 
  ref $self or return $result;
  defined $self->fault ? undef : $self->valueof($result);
};

# ======================================================================

package UDDI::Data;

use Carp ();

use vars qw(@ISA $AUTOLOAD @EXPORT_OK %EXPORT_TAGS);
@ISA = qw(SOAP::Data);

my @elements = (with => qw/accessPoint address addressLine authInfo authToken bindingDetail bindingKey bindingTemplate bindingTemplates businessDetail businessDetailExt businessEntity businessEntityExt businessInfo businessInfos businessKey businessList businessService businessServices categoryBag contact contacts description discoveryURL discoveryURLs dispositionReport email errInfo findQualifier findQualifiers hostingRedirector identifierBag instanceDetails instanceParms keyValue keyedReference name overviewDoc overviewURL personName phone registeredInfo result serviceDetail serviceInfo serviceInfos serviceKey serviceList tModel tModelBag tModelDetail tModelInfo tModelInfos tModelInstanceDetails tModelInstanceInfo tModelKey tModelList uploadRegister/);
@EXPORT_OK = (@elements);
%EXPORT_TAGS = ('all' => [@EXPORT_OK]);

use overload fallback => 1, '""' => sub { shift->SUPER::value };

use vars qw(%elements %attributes);
%elements = (get_serviceDetail=>{serviceKey=>1},find_tModel=>{categoryBag=>1,name=>1,identifierBag=>1,findQualifiers=>1},tModelInstanceInfo=>{instanceDetails=>1,description=>1},address=>{addressLine=>1},categoryBag=>{keyedReference=>1},save_binding=>{authInfo=>1,bindingTemplate=>1},businessEntity=>{categoryBag=>1,businessServices=>1,name=>1,description=>1,identifierBag=>1,discoveryURLs=>1,contacts=>1},businessInfos=>{businessInfo=>1},find_business=>{categoryBag=>1,name=>1,identifierBag=>1,discoveryURLs=>1,findQualifiers=>1,tModelBag=>1},get_bindingDetail=>{bindingKey=>1},identifierBag=>{keyedReference=>1},get_businessDetailExt=>{businessKey=>1},businessServices=>{businessService=>1},tModelInfo=>{name=>1},find_service=>{categoryBag=>1,name=>1,findQualifiers=>1,tModelBag=>1},dispositionReport=>{result=>1},authToken=>{authInfo=>1},get_tModelDetail=>{tModelKey=>1},delete_tModel=>{tModelKey=>1,authInfo=>1},bindingTemplate=>{tModelInstanceDetails=>1,accessPoint=>1,description=>1,hostingRedirector=>1},tModelDetail=>{tModel=>1},businessInfo=>{serviceInfos=>1,name=>1,description=>1},get_registeredInfo=>{authInfo=>1},businessEntityExt=>{businessEntity=>1},registeredInfo=>{businessInfos=>1,tModelInfos=>1},find_binding=>{findQualifiers=>1,tModelBag=>1},serviceInfo=>{name=>1},get_businessDetail=>{businessKey=>1},delete_business=>{businessKey=>1,authInfo=>1},discoveryURLs=>{discoveryURL=>1},businessDetail=>{businessEntity=>1},contacts=>{contact=>1},tModelInstanceDetails=>{tModelInstanceInfo=>1},tModelList=>{tModelInfos=>1},delete_service=>{serviceKey=>1,authInfo=>1},tModelInfos=>{tModelInfo=>1},serviceDetail=>{businessService=>1},tModel=>{categoryBag=>1,name=>1,description=>1,identifierBag=>1,overviewDoc=>1},businessList=>{businessInfos=>1},bindingTemplates=>{bindingTemplate=>1},validate_categorization=>{businessEntity=>1,tModel=>1,businessService=>1,keyValue=>1,tModelKey=>1},contact=>{email=>1,personName=>1,phone=>1,description=>1,address=>1},discard_authToken=>{authInfo=>1},overviewDoc=>{overviewURL=>1,description=>1},delete_binding=>{bindingKey=>1,authInfo=>1},serviceList=>{serviceInfos=>1},bindingDetail=>{bindingTemplate=>1},tModelBag=>{tModelKey=>1},businessDetailExt=>{businessEntityExt=>1},serviceInfos=>{serviceInfo=>1},save_tModel=>{uploadRegister=>1,tModel=>1,authInfo=>1},findQualifiers=>{findQualifier=>1},save_business=>{businessEntity=>1,uploadRegister=>1,authInfo=>1},instanceDetails=>{instanceParms=>1,description=>1,overviewDoc=>1},businessService=>{categoryBag=>1,name=>1,bindingTemplates=>1,description=>1},save_service=>{businessService=>1,authInfo=>1},result=>{errInfo=>1});
%attributes = (get_serviceDetail=>{generic=>2},find_tModel=>{maxRows=>2,generic=>2},tModelInstanceInfo=>{tModelKey=>2},address=>{sortCode=>2,useType=>2},email=>{useType=>2},save_binding=>{generic=>2},businessEntity=>{authorizedName=>2,operator=>2,businessKey=>2},discoveryURL=>{useType=>2},find_business=>{maxRows=>2,generic=>2},get_bindingDetail=>{generic=>2},get_businessDetailExt=>{generic=>2},tModelInfo=>{tModelKey=>2},find_service=>{maxRows=>2,businessKey=>2,generic=>2},dispositionReport=>{truncated=>2,operator=>2,generic=>2},authToken=>{operator=>2,generic=>2},get_tModelDetail=>{generic=>2},bindingTemplate=>{serviceKey=>2,bindingKey=>2},delete_tModel=>{generic=>2},tModelDetail=>{truncated=>2,operator=>2,generic=>2},businessInfo=>{businessKey=>2},get_registeredInfo=>{generic=>2},registeredInfo=>{truncated=>2,operator=>2,generic=>2},phone=>{useType=>2},find_binding=>{maxRows=>2,serviceKey=>2,generic=>2},serviceInfo=>{serviceKey=>2,businessKey=>2},get_businessDetail=>{generic=>2},delete_business=>{generic=>2},businessDetail=>{truncated=>2,operator=>2,generic=>2},keyedReference=>{keyName=>2,keyValue=>2,tModelKey=>2},tModelList=>{truncated=>2,operator=>2,generic=>2},delete_service=>{generic=>2},serviceDetail=>{truncated=>2,operator=>2,generic=>2},tModel=>{authorizedName=>2,operator=>2,tModelKey=>2},businessList=>{truncated=>2,operator=>2,generic=>2},validate_categorization=>{generic=>2},contact=>{useType=>2},discard_authToken=>{generic=>2},delete_binding=>{generic=>2},serviceList=>{truncated=>2,operator=>2,generic=>2},bindingDetail=>{truncated=>2,operator=>2,generic=>2},hostingRedirector=>{bindingKey=>2},businessDetailExt=>{truncated=>2,operator=>2,generic=>2},get_authToken=>{userID=>2,generic=>2,cred=>2},save_tModel=>{generic=>2},errInfo=>{errCode=>2},save_business=>{generic=>2},accessPoint=>{URLType=>2},businessService=>{serviceKey=>2,businessKey=>2},save_service=>{generic=>2},result=>{keyType=>2,errno=>2});

sub new {
  my $self = shift;
  my $class = ref($self) || $self;

  unless (ref $self) {
    $self = $class->SUPER::new(@_, type => 'uddi');
  }
  return $self;
}

sub with {
  my $self = shift;
  $self = (__PACKAGE__->can($self) || Carp::croak "Don't know what to do with '$self'")->()
    unless ref $self && UNIVERSAL::isa($self => __PACKAGE__);

  my $name = $self->SUPER::name;
  my @values;
  while (@_) {
    my $data = shift;
    my($method, @value) = UNIVERSAL::isa($data => __PACKAGE__)
      ? ($data->SUPER::name, $data->value)
      : ($data, shift);
    exists $attributes{$name}{$method}
      ? $self->$method(@value)
      : push(@values, ($self->can($method) || Carp::croak "Don't know what to do with '$method'")->(@value));
  }
  $self->set_value([@values]);
}

sub _compileit {
  no strict 'refs';
  my $method = shift;
  *$method = sub { 

    # GENERATE element if no parameters: businessInfo()
    return __PACKAGE__->SUPER::name($method) 
      if !@_ && exists $elements{$method};

    die "Expected element (UDDI::Data) as parameter for $method()\n"
      if !ref $_[0] && exists $elements{$method};

    my $uddi = UNIVERSAL::isa($_[0] => __PACKAGE__);

    # MAKE ELEMENT: name('old')
    return __PACKAGE__->SUPER::name($method => @_) 
      if !$uddi;

    my $name = $_[0]->SUPER::name;

    # GET/SET ATTRIBUTE: businessInfo->businessKey
    return @_ > 1 
        ? scalar($_[0]->attr->{$method} = $_[1], $_[0])               # SET
        : __PACKAGE__->SUPER::name($method => $_[0]->attr->{$method}) # GET
      if exists $attributes{$name} && exists $attributes{$name}{$method};

    # GET ELEMENT: businessInfos->businessInfo
    my @elems = grep {
      ref $_ && UNIVERSAL::isa($_ => __PACKAGE__) && $_->SUPER::name eq $method
    } map {ref $_ eq 'ARRAY' ? @$_ : $_} $_[0]->value;
    return wantarray? @elems : $elems[0]
      if exists $elements{$name} && exists $elements{$name}{$method};

    # MAKE ELEMENT: businessInfos(businessInfo('something'))
    return __PACKAGE__->SUPER::name($method => @_) 
      if exists $elements{$method} && exists $elements{$method}{$name};

    Carp::croak "Don't know what to do with '$method' and '$name' elements";
  }
}

sub BEGIN { _compileit('name') }

sub AUTOLOAD {
  my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::') + 2);
  return if $method eq 'DESTROY';

  _compileit($method);
  goto &$AUTOLOAD;
}

# ======================================================================

package UDDI::Serializer;

use vars qw(@ISA);
@ISA = qw(SOAP::Serializer);

sub new { 
  my $self = shift;
  my $class = ref($self) || $self;

  unless (ref $self) {
    $self = $class->SUPER::new(
      attr => {},
      namespaces => {
        $SOAP::Constants::PREFIX_ENV ? ($SOAP::Constants::NS_ENV => $SOAP::Constants::PREFIX_ENV) : (),
      },
      autotype => 0,
      @_,
    );
  }
  return $self;
}

use overload; # protect from stringification in UDDI::Data
sub gen_id { overload::StrVal($_[1]) =~ /\((0x\w+)\)/o; $1 }

sub as_uddi { 
  my $self = shift;
  my($value, $name, $type, $attr) = @_;
  return $self->encode_array($value, $name, undef, $attr) if ref $value eq 'ARRAY';
  return $self->encode_hash($value, $name, undef, $attr) if ref $value eq 'HASH';
  [$name, {%{$attr || {}}}, ref $value ? ([$self->encode_object($value)], $self->gen_id($value)) : $value];
}                                                                                          

sub encode_array {
  my $self = shift;
  my $encoded = $self->SUPER::encode_array(@_);
  delete $encoded->[1]->{SOAP::Utils::qualify($self->encprefix => 'arrayType')};
  return $encoded;
}

# ======================================================================

package UDDI::Deserializer;

use vars qw(@ISA);
@ISA = qw(SOAP::Deserializer);

sub decode_value {
  my $self = shift;
  my $ref = shift;
  my($name, $attrs, $children, $value) = @$ref;

  # base class knows what to do with elements in SOAP namespace
  return $self->SUPER::decode_value($ref) 
    if exists $attrs->{href} || 
       (SOAP::Utils::splitlongname($name))[0] eq $SOAP::Constants::NS_ENV;

  UDDI::Data
    -> SOAP::Data::name($name)
    -> attr($attrs)
    -> set_value(ref $children && @$children ? map(scalar(($self->decode_object($_))[1]), @$children) : $value);
}

sub deserialize {
  bless shift->SUPER::deserialize(@_) => 'UDDI::SOM';
}

# ======================================================================

package UDDI::Lite;

use vars qw(@ISA $AUTOLOAD %EXPORT_TAGS);
use Exporter;
use Carp ();
@ISA = qw(SOAP::Lite Exporter);

BEGIN { # handle exports
  %EXPORT_TAGS = (
    'delete'   => [qw/delete_binding delete_business delete_service delete_tModel/],
    'auth'     => [qw/get_authToken discard_authToken get_registeredInfo/],
    'save'     => [qw/save_binding save_business save_service save_tModel/],
    'validate' => [qw/validate_categorization/],
    'find'     => [qw/find_binding find_business find_service find_tModel/],
    'get'      => [qw/get_bindingDetail get_businessDetail get_businessDetailExt get_serviceDetail get_tModelDetail/],
  );
  $EXPORT_TAGS{inquiry} = [map {@{$EXPORT_TAGS{$_}}} qw/find get/];
  $EXPORT_TAGS{publish} = [map {@{$EXPORT_TAGS{$_}}} qw/delete auth save validate/];
  $EXPORT_TAGS{all} =     [map {@{$EXPORT_TAGS{$_}}} qw/inquiry publish/];
  Exporter::export_ok_tags('all');
}

sub new { 
  my $self = shift;
  my $class = ref($self) || $self;

  unless (ref $self) {
    $self = $class->SUPER::new(
      on_action    => sub {'""'},
      serializer   => UDDI::Serializer->new,   # register UDDI Serializer
      deserializer => UDDI::Deserializer->new, # and Deserializer
      @_,
    );
  }
  return $self;
}

sub AUTOLOAD {
  my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::') + 2);
  return if $method eq 'DESTROY';

  no strict 'refs';
  *$AUTOLOAD = sub { 
    return shift->call($method => @_) if UNIVERSAL::isa($_[0] => __PACKAGE__);
    my $som = (__PACKAGE__->self || Carp::croak "Method call on unspecified object. Died")->call($method => @_);
    UNIVERSAL::isa($som => 'SOAP::SOM') ? $som->result : $som;
  };
  goto &$AUTOLOAD;
}

sub call { SOAP::Trace::trace('()'); 
  my $self = shift;
  my $method = shift;
  my @parameters;
  my $attr = ref $_[0] eq 'HASH' ? shift() : {};
  while (@_) {
    push(@parameters, UNIVERSAL::isa($_[0] => 'UDDI::Data') 
      ? shift : SOAP::Data->name(shift, shift));
  }
  my $message = SOAP::Data
    -> name($method => \SOAP::Data->value(@parameters))
    -> attr({xmlns=>'urn:uddi-org:api', generic => '1.0', %$attr});

  my $serializer = $self->serializer;
  $serializer->on_nonserialized($self->on_nonserialized);

  my $respond = $self->transport->send_receive(
    endpoint => $self->endpoint, 
    action   => $self->on_action->($self->uri),
    envelope => $serializer->envelope(freeform => $message), 
    encoding => $serializer->encoding,
  );

  return $respond if $self->outputxml;

  unless ($self->transport->is_success) {
    my $result = eval { $self->deserializer->deserialize($respond) } if $respond;
    return $self->on_fault->($self, $@ ? $respond : $result) || $result;
  }

  return unless $respond; # nothing to do for one-ways
  return $self->deserializer->deserialize($respond);
}

# ======================================================================

1;

__END__


package Pod::JSchema::Block::JSCHEMA;

use Moose;
use JSON -support_by_pp;
use Pod::JSchema::Schema;

extends 'Pod::JSchema::Block';

has [qw'param_schema return_schema'] => (is => 'ro');
has method => ( is => 'ro' );

sub tags { qw'JSCHEMA' }

sub _parse{
    my $pkg  = shift;
    my $json = shift;
    
    my $data = JSON->new->allow_barekey->relaxed->decode( $json );
    
    my $params = $data->{parameters} || $data->{params} || $data->{in};
    my $return = $data->{returns}    || $data->{return} || $data->{out};
    
    my %out = ( type => 'jschema' );
    if ( $data->{method} ){
        $out{method} = $data->{method};
    }
    
    if ($params){
        $out{param_schema} = Pod::JSchema::Schema->new ( schema => _shorthand_to_jschema_recurse($params) );
    }
    if ($return){
        $out{return_schema} = Pod::JSchema::Schema->new ( schema => _shorthand_to_jschema_recurse($return) );
    }
    
    return __PACKAGE__->new ( \%out );
}


my %json_types = ( map{ $_ => 1 } qw'string number integer boolean object array null any' );

sub _shorthand_to_jschema_recurse{
    my $in = shift;
    
    my $ref = ref($in);
    my $out = {};
    if( !$ref && length($in) ){
        
        my @parts = split(/\s*:\s*/, $in);
        my ($type) = grep { $json_types{lc($_)} } @parts;
        my ($req)  = grep { $_ =~ /^(r|req|required)$/i } @parts;
        my %remove = map {$_ => 1} grep {defined} ($type, $req);
        
        @parts = grep { !$remove{$_} } @parts;
        my ($desc) = $parts[0] if scalar(@parts) && length( $parts[0] ) > 9;
        
        $out->{type} = defined $type ? lc($type) : 'string';
        $out->{required} = JSON::true if ( defined $req );
        $out->{description} = $desc if defined $desc;
        
    }elsif ( $ref eq 'HASH'){
        $out = {
                type => 'object',
                properties => {},
            };
        
        map { $out->{properties}{$_} = _shorthand_to_jschema_recurse( $in->{$_} ) } keys %$in;
        
    }elsif( $ref eq 'ARRAY' ){
        die "incorrect number of elements in array, expect just one" if @$in != 1;
        $out = {
            type => 'array',
            items => _shorthand_to_jschema_recurse( $in->[0] ),
        };
    }
    
    return $out;
}


sub markdown{
    my $self = shift;
    
    my $out;
    my $method = ucfirst( $self->method );
    
    $out .= "$method\n";
    $out .= ( ("-" x length($method)) . "\n\n");
    
    if ( $self->param_schema ){
        $out .= "Parameters:  \n\n";
        $out .= $self->param_schema->markdown;
        $out .= "\n";
    }
    
    if ( $self->return_schema ){
        $out .= "Returns:  \n\n";
        $out .= $self->return_schema->markdown;
        $out .=  "\n";
    }
    
    return $out;
}



1;
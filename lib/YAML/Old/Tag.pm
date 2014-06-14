use strict; use warnings;
package YAML::Old::Tag;
$YAML::Old::Tag::VERSION = '0.93';
use overload '""' => sub { ${$_[0]} };

sub new {
    my ($class, $self) = @_;
    bless \$self, $class
}

sub short {
    ${$_[0]}
}

sub canonical {
    ${$_[0]}
}

1;

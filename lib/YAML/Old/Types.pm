package YAML::Old::Types;

use YAML::Old::Mo;
use YAML::Old::Node;

# XXX These classes and their APIs could still use some refactoring,
# but at least they work for now.
#-------------------------------------------------------------------------------
package YAML::Old::Type::blessed;

use YAML::Old::Mo; # XXX

sub yaml_dump {
    my $self = shift;
    my ($value) = @_;
    my ($class, $type) = YAML::Old::Mo::Object->node_info($value);
    no strict 'refs';
    my $kind = lc($type) . ':';
    my $tag = ${$class . '::ClassTag'} ||
              "!perl/$kind$class";
    if ($type eq 'REF') {
        YAML::Old::Node->new(
            {(&YAML::VALUE, ${$_[0]})}, $tag
        );
    }
    elsif ($type eq 'SCALAR') {
        $_[1] = $$value;
        YAML::Old::Node->new($_[1], $tag);
    } else {
        YAML::Old::Node->new($value, $tag);
    }
}

#-------------------------------------------------------------------------------
package YAML::Old::Type::undef;

sub yaml_dump {
    my $self = shift;
}

sub yaml_load {
    my $self = shift;
}

#-------------------------------------------------------------------------------
package YAML::Old::Type::glob;

sub yaml_dump {
    my $self = shift;
    my $ynode = YAML::Old::Node->new({}, '!perl/glob:');
    for my $type (qw(PACKAGE NAME SCALAR ARRAY HASH CODE IO)) {
        my $value = *{$_[0]}{$type};
        $value = $$value if $type eq 'SCALAR';
        if (defined $value) {
            if ($type eq 'IO') {
                my @stats = qw(device inode mode links uid gid rdev size
                               atime mtime ctime blksize blocks);
                undef $value;
                $value->{stat} = YAML::Old::Node->new({});
                if ($value->{fileno} = fileno(*{$_[0]})) {
                    local $^W;
                    map {$value->{stat}{shift @stats} = $_} stat(*{$_[0]});
                    $value->{tell} = tell(*{$_[0]});
                }
            }
            $ynode->{$type} = $value;
        }
    }
    return $ynode;
}

sub yaml_load {
    my $self = shift;
    my ($node, $class, $loader) = @_;
    my ($name, $package);
    if (defined $node->{NAME}) {
        $name = $node->{NAME};
        delete $node->{NAME};
    }
    else {
        $loader->warn('YAML_LOAD_WARN_GLOB_NAME');
        return undef;
    }
    if (defined $node->{PACKAGE}) {
        $package = $node->{PACKAGE};
        delete $node->{PACKAGE};
    }
    else {
        $package = 'main';
    }
    no strict 'refs';
    if (exists $node->{SCALAR}) {
        *{"${package}::$name"} = \$node->{SCALAR};
        delete $node->{SCALAR};
    }
    for my $elem (qw(ARRAY HASH CODE IO)) {
        if (exists $node->{$elem}) {
            if ($elem eq 'IO') {
                $loader->warn('YAML_LOAD_WARN_GLOB_IO');
                delete $node->{IO};
                next;
            }
            *{"${package}::$name"} = $node->{$elem};
            delete $node->{$elem};
        }
    }
    for my $elem (sort keys %$node) {
        $loader->warn('YAML_LOAD_WARN_BAD_GLOB_ELEM', $elem);
    }
    return *{"${package}::$name"};
}

#-------------------------------------------------------------------------------
package YAML::Old::Type::code;

my $dummy_warned = 0;
my $default = '{ "DUMMY" }';

sub yaml_dump {
    my $self = shift;
    my $code;
    my ($dumpflag, $value) = @_;
    my ($class, $type) = YAML::Old::Mo::Object->node_info($value);
    my $tag = "!perl/code";
    $tag .= ":$class" if defined $class;
    if (not $dumpflag) {
        $code = $default;
    }
    else {
        bless $value, "CODE" if $class;
        eval { use B::Deparse };
        return if $@;
        my $deparse = B::Deparse->new();
        eval {
            local $^W = 0;
            $code = $deparse->coderef2text($value);
        };
        if ($@) {
            warn YAML::YAML_DUMP_WARN_DEPARSE_FAILED() if $^W;
            $code = $default;
        }
        bless $value, $class if $class;
        chomp $code;
        $code .= "\n";
    }
    $_[2] = $code;
    YAML::Old::Node->new($_[2], $tag);
}

sub yaml_load {
    my $self = shift;
    my ($node, $class, $loader) = @_;
    if ($loader->load_code) {
        my $code = eval "package main; sub $node";
        if ($@) {
            $loader->warn('YAML_LOAD_WARN_PARSE_CODE', $@);
            return sub {};
        }
        else {
            CORE::bless $code, $class if $class;
            return $code;
        }
    }
    else {
        return CORE::bless sub {}, $class if $class;
        return sub {};
    }
}

#-------------------------------------------------------------------------------
package YAML::Old::Type::ref;

sub yaml_dump {
    my $self = shift;
    YAML::Old::Node->new({(&YAML::VALUE, ${$_[0]})}, '!perl/ref')
}

sub yaml_load {
    my $self = shift;
    my ($node, $class, $loader) = @_;
    $loader->die('YAML_LOAD_ERR_NO_DEFAULT_VALUE', 'ptr')
      unless exists $node->{&YAML::VALUE};
    return \$node->{&YAML::VALUE};
}

#-------------------------------------------------------------------------------
package YAML::Old::Type::regexp;

# XXX Be sure to handle blessed regexps (if possible)
sub yaml_dump {
    die "YAML::Old::Type::regexp::yaml_dump not currently implemented";
}

use constant _QR_TYPES => {
    '' => sub { qr{$_[0]} },
    x => sub { qr{$_[0]}x },
    i => sub { qr{$_[0]}i },
    s => sub { qr{$_[0]}s },
    m => sub { qr{$_[0]}m },
    ix => sub { qr{$_[0]}ix },
    sx => sub { qr{$_[0]}sx },
    mx => sub { qr{$_[0]}mx },
    si => sub { qr{$_[0]}si },
    mi => sub { qr{$_[0]}mi },
    ms => sub { qr{$_[0]}sm },
    six => sub { qr{$_[0]}six },
    mix => sub { qr{$_[0]}mix },
    msx => sub { qr{$_[0]}msx },
    msi => sub { qr{$_[0]}msi },
    msix => sub { qr{$_[0]}msix },
};

sub yaml_load {
    my $self = shift;
    my ($node, $class) = @_;
    return qr{$node} unless $node =~ /^\(\?([\^\-xism]*):(.*)\)\z/s;
    my ($flags, $re) = ($1, $2);
    $flags =~ s/-.*//;
    $flags =~ s/^\^//;
    my $sub = _QR_TYPES->{$flags} || sub { qr{$_[0]} };
    my $qr = &$sub($re);
    bless $qr, $class if length $class;
    return $qr;
}

1;

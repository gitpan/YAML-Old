use strict; use warnings;
package YAML::Old;
our $VERSION = '1.07';

use YAML::Old::Mo;

use Exporter;
push @YAML::Old::ISA, 'Exporter';
our @EXPORT = qw{ Dump Load };
our @EXPORT_OK = qw{ freeze thaw DumpFile LoadFile Bless Blessed };

use YAML::Old::Node; # XXX This is a temp fix for Module::Build

# XXX This VALUE nonsense needs to go.
{
    package
    YAML;
    use constant VALUE => "\x07YAML\x07VALUE\x07";
}

# YAML Object Properties
has dumper_class => default => sub {'YAML::Old::Dumper'};
has loader_class => default => sub {'YAML::Old::Loader'};
has dumper_object => default => sub {$_[0]->init_action_object("dumper")};
has loader_object => default => sub {$_[0]->init_action_object("loader")};

sub Dump {
    my $yaml = YAML::Old->new;
    $yaml->dumper_class($YAML::Old::DumperClass)
        if $YAML::Old::DumperClass;
    return $yaml->dumper_object->dump(@_);
}

sub Load {
    my $yaml = YAML::Old->new;
    $yaml->loader_class($YAML::Old::LoaderClass)
        if $YAML::Old::LoaderClass;
    return $yaml->loader_object->load(@_);
}

{
    no warnings 'once';
    # freeze/thaw is the API for Storable string serialization. Some
    # modules make use of serializing packages on if they use freeze/thaw.
    *freeze = \ &Dump;
    *thaw   = \ &Load;
}

sub DumpFile {
    my $OUT;
    my $filename = shift;
    if (ref $filename eq 'GLOB') {
        $OUT = $filename;
    }
    else {
        my $mode = '>';
        if ($filename =~ /^\s*(>{1,2})\s*(.*)$/) {
            ($mode, $filename) = ($1, $2);
        }
        open $OUT, $mode, $filename
          or YAML::Old::Mo::Object->die('YAML_DUMP_ERR_FILE_OUTPUT', $filename, $!);
    }
    binmode $OUT, ':utf8';  # if $Config{useperlio} eq 'define';
    local $/ = "\n"; # reset special to "sane"
    print $OUT Dump(@_);
}

sub LoadFile {
    my $IN;
    my $filename = shift;
    if (ref $filename eq 'GLOB') {
        $IN = $filename;
    }
    else {
        open $IN, '<', $filename
          or YAML::Old::Mo::Object->die('YAML_LOAD_ERR_FILE_INPUT', $filename, $!);
    }
    binmode $IN, ':utf8';  # if $Config{useperlio} eq 'define';
    return Load(do { local $/; <$IN> });
}

sub init_action_object {
    my $self = shift;
    my $object_class = (shift) . '_class';
    my $module_name = $self->$object_class;
    eval "require $module_name";
    $self->die("Error in require $module_name - $@")
        if $@ and "$@" !~ /Can't locate/;
    my $object = $self->$object_class->new;
    $object->set_global_options;
    return $object;
}

my $global = {};
sub Bless {
    require YAML::Old::Dumper::Base;
    YAML::Old::Dumper::Base::bless($global, @_)
}
sub Blessed {
    require YAML::Old::Dumper::Base;
    YAML::Old::Dumper::Base::blessed($global, @_)
}
sub global_object { $global }

1;

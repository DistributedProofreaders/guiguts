# $File: //member/autrijus/Module-ScanDeps/lib/Module/ScanDeps.pm $ $Author: autrijus $
# $Revision: #17 $ $Change: 10181 $ $DateTime: 2004/02/23 21:11:48 $ vim: expandtab shiftwidth=4

package Module::ScanDeps;
use vars qw( $VERSION @EXPORT @EXPORT_OK );

$VERSION   = '0.40';
@EXPORT    = qw( scan_deps scan_deps_runtime );
@EXPORT_OK = qw( scan_line scan_chunk add_deps scan_deps_runtime );

use strict;

use Config;
use Exporter;
use base 'Exporter';
use constant dl_ext  => ".$Config{dlext}";
use constant lib_ext => $Config{lib_ext};

use Cwd ();
use File::Path ();
use File::Temp ();
use File::Basename ();
use FileHandle;

my $SeenTk;

# Pre-loaded module dependencies {{{
my %Preload = (
    'AnyDBM_File.pm'  => [qw( SDBM_File.pm )],
    'Authen/SASL.pm'  => 'sub',
    'Crypt/Random.pm' => sub {
        _glob_in_inc('Crypt/Random/Provider', 1);
    },
    'Crypt/Random/Generator.pm' => sub {
        _glob_in_inc('Crypt/Random/Provider', 1);
    },
    'DBI.pm' => sub {
        grep !/\bProxy\b/, _glob_in_inc('DBD', 1);
    },
    'Device/SerialPort.pm' => [ qw(
        termios.ph asm/termios.ph sys/termiox.ph sys/termios.ph sys/ttycom.ph
    ) ],

    #   'Encode.pm'                         => 'sub',
    'ExtUtils/MakeMaker.pm' => sub {
        grep /\bMM_/, _glob_in_inc('ExtUtils', 1);
    },
    'File/Basename.pm' => [qw( re.pm )],
    'File/Spec.pm'     => sub {
        require File::Spec;
        map { my $name = $_; $name =~ s!::!/!g; "$name.pm" } @File::Spec::ISA;
    },
    'HTTP/Message.pm' => [ qw(
        URI/URL.pm          URI.pm
    ) ],
    'IO.pm' => [ qw(
        IO/Handle.pm        IO/Seekable.pm      IO/File.pm
        IO/Pipe.pm          IO/Socket.pm        IO/Dir.pm
    ) ],
    'IO/Socket.pm'     => [qw( IO/Socket/UNIX.pm )],
    'LWP/UserAgent.pm' => [ qw(
        URI/URL.pm          URI/http.pm         LWP/Protocol/http.pm
        LWP/Protocol/https.pm
    ) ],
    'Locale/Maketext/Lexicon.pm'    => 'sub',
    'Locale/Maketext/GutsLoader.pm' => [qw( Locale/Maketext/Guts.pm )],
    'Math/BigInt.pm'                => 'sub',
    'Math/BigFloat.pm'              => 'sub',
    'Module/Build.pm'               => 'sub',
    'MIME/Decoder.pm'               => 'sub',
    'Net/DNS/RR.pm'                 => 'sub',
    'Net/FTP.pm'                    => 'sub',
    'Net/SSH/Perl'                  => 'sub',
    'Regexp/Common.pm'              => 'sub',
    'SOAP/Lite.pm'                  => sub {
        (($] >= 5.008 ? ('utf8.pm') : ()), _glob_in_inc('SOAP/Transport', 1));
    },
    'SQL/Parser.pm' => sub {
        _glob_in_inc('SQL/Dialects', 1);
    },
    'SerialJunk.pm' => [ qw(
        termios.ph asm/termios.ph sys/termiox.ph sys/termios.ph sys/ttycom.ph
    ) ],
    'Template.pm'      => 'sub',
    'Term/ReadLine.pm' => 'sub',
    'Tk.pm'            => sub {
        $SeenTk = 1;
        'Tk/FileSelect.pm';
    },
    'Tk/Balloon.pm'     => [qw( Tk/balArrow.xbm )],
    'Tk/BrowseEntry.pm' => [qw( Tk/cbxarrow.xbm )],
    'Tk/ColorEditor.pm' => [qw( Tk/ColorEdit.xpm )],
    'Tk/FBox.pm'        => [qw( Tk/folder.xpm Tk/file.xpm )],
    'Tk/Toplevel.pm'    => [qw( Tk/Wm.pm )],
    'URI.pm'            => sub {
        grep !/.\b[_A-Z]/, _glob_in_inc('URI', 1);
    },
    'Win32/EventLog.pm'    => [qw( Win32/IPC.pm )],
    'Win32/TieRegistry.pm' => [qw( Win32API/Registry.pm )],
    'Win32/SystemInfo.pm'  => [qw( Win32/cpuspd.dll )],
    'XML/Parser.pm'        => sub {
        _glob_in_inc('XML/Parser/Style', 1),
        _glob_in_inc('XML/Parser/Encodings', 1),
    },
    'XML/Parser/Expat.pm' => sub {
        ($] >= 5.008) ? ('utf8.pm') : ();
    },
    'XML/SAX.pm' => [qw( XML/SAX/ParserDetails.ini ) ],
    'XMLRPC/Lite.pm' => sub {
        _glob_in_inc('XMLRPC/Transport', 1),;
    },
    'diagnostics.pm' => sub {
        _find_in_inc('Pod/perldiag.pod')
          ? 'Pod/perldiag.pl'
          : 'pod/perldiag.pod';
    },
    'utf8.pm' => [
        'utf8_heavy.pl', do {
            my $dir = 'unicore';
            my @subdirs = qw( To );
            my @files = map "$dir/lib/$_->{name}", _glob_in_inc("$dir/lib");

            if (@files) {
                # 5.8.x
                push @files, (map "$dir/$_.pl", qw( Exact Canonical ));
            }
            else {
                # 5.6.x
                $dir = 'unicode';
                @files = map "$dir/Is/$_->{name}", _glob_in_inc("$dir/Is")
                  or return;
                push @subdirs, 'In';
            }

            foreach my $subdir (@subdirs) {
                foreach (_glob_in_inc("$dir/$subdir")) {
                    push @files, "$dir/$subdir/$_->{name}";
                }
            }
            @files;
        }
    ],
    'charnames.pm' => [
        _find_in_inc('unicore/Name.pl') ? 'unicore/Name.pl' : 'unicode/Name.pl'
    ],
);

# }}}

my $Keys = 'files|keys|recurse|rv|skip|first|execute|compile';
sub scan_deps {
    my %args = (
        rv => {},
        (@_ and $_[0] =~ /^(?:$Keys)$/o) ? @_ : (files => [@_], recurse => 1)
    );

    scan_deps_static(\%args);

    if ($args{execute} or $args{compile}) {
        scan_deps_runtime(
            rv      => $args{rv},
            files   => $args{files},
            execute => $args{execute},
            compile => $args{compile},
            skip    => $args{skip}
        );
    }

    return ($args{rv});
}

sub scan_deps_static {
    my ($args) = @_;
    my ($files, $keys, $recurse, $rv, $skip, $first, $execute, $compile) =
      @$args{qw( files keys recurse rv skip first execute compile )};

    $rv   ||= {};
    $skip ||= {};

    foreach my $file (@{$files}) {
        my $key = shift @{$keys};
        next if $skip->{$file}++;

        local *FH;
        open FH, $file or die "Cannot open $file: $!";

        $SeenTk = 0;

        # Line-by-line scanning
        LINE:
        while (<FH>) {
            chomp(my $line = $_);
            foreach my $pm (scan_line($line)) {
                last LINE if $pm eq '__END__';

                if ($pm eq '__POD__') {
                    while (<FH>) { last if (/^=cut/) }
                    next LINE;
                }

                $pm = 'CGI/Apache.pm' if /^Apache(?:\.pm)$/;

                add_deps(
                    used_by => $key,
                    rv      => $rv,
                    modules => [$pm],
                    skip    => $skip
                );

                my $preload = $Preload{$pm} or next;
                if ($preload eq 'sub') {
                    $pm =~ s/\.pm$//i;
                    $preload = [ _glob_in_inc($pm, 1) ];
                }
                elsif (UNIVERSAL::isa($preload, 'CODE')) {
                    $preload = [ $preload->($pm) ];
                }

                add_deps(
                    used_by => $key,
                    rv      => $rv,
                    modules => $preload,
                    skip    => $skip
                );
            }
        }
        close FH;

        # }}}
    }

    # Top-level recursion handling {{{
    while ($recurse) {
        my $count = keys %$rv;
        my @files = sort grep -T $_->{file}, values %$rv;
        scan_deps_static({
            files   => [ map $_->{file}, @files ],
            keys    => [ map $_->{key},  @files ],
            rv      => $rv,
            skip    => $skip,
            recurse => 0,
        }) or ($args->{_deep} and return);
        last if $count == keys %$rv;
    }

    # }}}

    return $rv;
}

sub scan_deps_runtime {
    my %args = (
        perl => $^X,
        rv   => {},
        (@_ and $_[0] =~ /^(?:$Keys)$/o) ? @_ : (files => [@_], recurse => 1)
    );
    my ($files, $rv, $execute, $compile, $skip, $perl) =
      @args{qw( files rv execute compile skip perl )};

    $files = (ref($files)) ? $files : [$files];

    my ($inchash, $incarray, $dl_shared_objects) = ({}, [], []);
    if ($compile) {
        my $file;

        foreach $file (@$files) {
            ($inchash, $dl_shared_objects, $incarray) = ({}, [], []);
            _compile($perl, $file, $inchash, $dl_shared_objects, $incarray);

            my $rv_sub = _make_rv($inchash, $dl_shared_objects, $incarray);
            _merge_rv($rv_sub, $rv);
        }
    }
    elsif ($execute) {
        my $excarray = (ref($execute)) ? $execute : [@$files];
        my $exc;
        my $first_flag = 1;
        foreach $exc (@$excarray) {
            ($inchash, $dl_shared_objects, $incarray) = ({}, [], []);
            _execute(
                $perl, $exc, $inchash, $dl_shared_objects, $incarray,
                $first_flag
            );
            $first_flag = 0;
        }

        my $rv_sub = _make_rv($inchash, $dl_shared_objects, $incarray);
        _merge_rv($rv_sub, $rv);
    }

    return ($rv);
}

sub scan_line {
    my $line = shift;
    my %found;

    return '__END__' if $line =~ /^__(?:END|DATA)__$/;
    return '__POD__' if $line =~ /^=\w/;

    $line =~ s/\s*#.*$//;
    $line =~ s/[\\\/]+/\//g;

    foreach (split(/;/, $line)) {
        return if /^\s*(use|require)\s+[\d\._]+/;

        if (my ($libs) = /\b(?:use\s+lib\s+|(?:unshift|push)\W+\@INC\W+)(.+)/)
        {
            my $archname =
              defined($Config{archname}) ? $Config{archname} : '';
            my $ver = defined($Config{version}) ? $Config{version} : '';
            foreach (grep(/\w/, split(/["';() ]/, $libs))) {
                unshift(@INC, "$_/$ver")           if -d "$_/$ver";
                unshift(@INC, "$_/$archname")      if -d "$_/$archname";
                unshift(@INC, "$_/$ver/$archname") if -d "$_/$ver/$archname";
            }
            next;
        }

        $found{$_}++ for scan_chunk($_);
    }

    return sort keys %found;
}

sub scan_chunk {
    my $chunk = shift;

    # Module name extraction heuristics {{{
    my $module = eval {
        $_ = $chunk;

        return [ 'base.pm',
            map { s{::}{/}g; "$_.pm" }
              grep { length and !/^q[qw]?$/ } split(/[^\w:]+/, $1) ]
          if /^\s* use \s+ base \s+ (.*)/x;

        return [ 'encoding.pm',
            map { _find_encoding($_) }
              grep { length and !/^q[qw]?$/ } split(/[^\w:]+/, $1) ]
          if /^\s* use \s+ encoding \s+ (.*)/x;

        return $1 if /(?:^|\s)(?:use|no|require)\s+([\w:\.\-\\\/\"\']+)/;
        return $1
          if /(?:^|\s)(?:use|no|require)\s+\(\s*([\w:\.\-\\\/\"\']+)\s*\)/;

        if (   s/(?:^|\s)eval\s+\"([^\"]+)\"/$1/
            or s/(?:^|\s)eval\s*\(\s*\"([^\"]+)\"\s*\)/$1/)
        {
            return $1 if /(?:^|\s)(?:use|no|require)\s+([\w:\.\-\\\/\"\']*)/;
        }

        return "File/Glob.pm" if /<[^>]*[^\$\w>][^>]*>/;
        return "DBD/$1.pm"    if /\b[Dd][Bb][Ii]:(\w+):/;
        if (/(?::encoding|\b(?:en|de)code)\(\s*['"]?([-\w]+)/) {
            my $mod = _find_encoding($1);
            return $mod if $mod;
        }
        return $1 if /(?:^|\s)(?:do|require)\s+[^"]*"(.*?)"/;
        return $1 if /(?:^|\s)(?:do|require)\s+[^']*'(.*?)'/;
        return $1 if /[^\$]\b([\w:]+)->\w/ and $1 ne 'Tk';
        return $1 if /\b(\w[\w:]*)::\w+\(/;

        if ($SeenTk) {
            my @modules;
            while (/->\s*([A-Z]\w+)/g) {
                push @modules, "Tk/$1.pm";
            }
            while (/->\s*Scrolled\W+([A-Z]\w+)/g) {
                push @modules, "Tk/$1.pm";
                push @modules, "Tk/Scrollbar.pm";
            }
            return \@modules;
        }
        return;
    };

    # }}}

    return unless defined($module);
    return wantarray ? @$module : $module->[0] if ref($module);

    $module =~ s/^['"]//;
    return unless $module =~ /^\w/;

    $module =~ s/\W+$//;
    $module =~ s/::/\//g;
    return if $module =~ /^(?:[\d\._]+|'.*[^']|".*[^"])$/;

    $module .= ".pm" unless $module =~ /\./;
    return $module;
}

sub _find_encoding {
    return unless $] >= 5.008 and eval { require Encode; %Encode::ExtModule };

    my $mod = $Encode::ExtModule{ Encode::find_encoding($_[0])->name }
      or return;
    $mod =~ s{::}{/}g;
    return "$mod.pm";
}

sub _add_info {
    my ($rv, $module, $file, $used_by, $type) = @_;
    return unless defined($module) and defined($file);

    $rv->{$module} ||= {
        file => $file,
        key  => $module,
        type => $type,
    };

    push @{ $rv->{$module}{used_by} }, $used_by
      if defined($used_by)
      and $used_by ne $module
      and !grep { $_ eq $used_by } @{ $rv->{$module}{used_by} };
}

sub add_deps {
    my %args =
      ((@_ and $_[0] =~ /^(?:modules|rv|used_by)$/)
        ? @_
        : (rv => (ref($_[0]) ? shift(@_) : undef), modules => [@_]));

    my $rv   = $args{rv}   || {};
    my $skip = $args{skip} || {};
    my $used_by = $args{used_by};

    foreach my $module (@{ $args{modules} }) {
        next if exists $rv->{$module};

        my $file = _find_in_inc($module) or next;
        next if $skip->{$file};
        my $type = 'module';
        $type = 'data' unless $file =~ /\.p[mh]$/i;
        _add_info($rv, $module, $file, $used_by, $type);

        if ($module =~ /(.*?([^\/]*))\.p[mh]$/i) {
            my ($path, $basename) = ($1, $2);

            foreach (_glob_in_inc("auto/$path")) {
                next if $_->{file} =~ m{\bauto/$path/.*/};  # weed out subdirs
                next if $_->{name} =~ m/(?:^|\/)\.(?:exists|packlist)$/;
                my $ext = lc($1) if $_->{name} =~ /(\.[^.]+)$/;
                next if $ext eq lc(lib_ext());
                my $type = 'shared' if $ext eq lc(dl_ext());
                $type = 'autoload' if $ext eq '.ix' or $ext eq '.al';
                $type ||= 'data';

                _add_info($rv, "auto/$path/$_->{name}", $_->{file}, $module,
                    $type);
            }
        }
    }

    return $rv;
}

sub _find_in_inc {
    my $file = shift;

    # absolute file names
    return $file if -f $file;

    foreach my $dir (grep !/\bBSDPAN\b/, @INC) {
        return "$dir/$file" if -f "$dir/$file";
    }
    return;
}

sub _glob_in_inc {
    my $subdir  = shift;
    my $pm_only = shift;
    my @files;

    require File::Find;

    foreach my $dir (map "$_/$subdir", grep !/\bBSDPAN\b/, @INC) {
        next unless -d $dir;
        File::Find::find(
            sub {
                my $name = $File::Find::name;
                $name =~ s!^\Q$dir\E/!!;
                next if $pm_only and lc($name) !~ /\.pm$/;
                push @files, $pm_only
                  ? "$subdir/$name"
                  : {             file => $File::Find::name,
                    name => $name,
                  }
                  if -f;
            },
            $dir
        );
    }

    return @files;
}

# App::Packer compatibility functions

sub new {
    my ($class, $self) = @_;
    return bless($self ||= {}, $class);
}

sub set_file {
    my $self = shift;
    foreach my $script (@_) {
        my $basename = $script;
        $basename =~ s/.*\///;
        $self->{main} = {
            key  => $basename,
            file => $script,
        };
    }
}

sub set_options {
    my $self = shift;
    my %args = @_;
    foreach my $module (@{ $args{add_modules} }) {
        $module =~ s/::/\//g;
        $module .= '.pm' unless $module =~ /\.p[mh]$/i;
        my $file = _find_in_inc($module) or next;
        $self->{files}{$module} = $file;
    }
}

sub calculate_info {
    my $self = shift;
    my $rv   = scan_deps(
        keys  => [ $self->{main}{key}, sort keys %{ $self->{files} }, ],
        files => [ $self->{main}{file},
            map { $self->{files}{$_} } sort keys %{ $self->{files} },
        ],
        recurse => 1,
    );

    my $info = {
        main => {  file     => $self->{main}{file},
            store_as => $self->{main}{key},
        },
    };

    my %cache = ($self->{main}{key} => $info->{main});
    foreach my $key (sort keys %{ $self->{files} }) {
        my $file = $self->{files}{$key};

        $cache{$key} = $info->{modules}{$key} = {
            file     => $file,
            store_as => $key,
            used_by  => [ $self->{main}{key} ],
        };
    }

    foreach my $key (sort keys %{$rv}) {
        my $val = $rv->{$key};
        if ($cache{ $val->{key} }) {
            push @{ $info->{ $val->{type} }->{ $val->{key} }->{used_by} },
              @{ $val->{used_by} };
        }
        else {
            $cache{ $val->{key} } = $info->{ $val->{type} }->{ $val->{key} } =
              {        file     => $val->{file},
                store_as => $val->{key},
                used_by  => $val->{used_by},
              };
        }
    }

    $self->{info} = { main => $info->{main} };

    foreach my $type (sort keys %{$info}) {
        next if $type eq 'main';

        my @val;
        if (UNIVERSAL::isa($info->{$type}, 'HASH')) {
            foreach my $val (sort values %{ $info->{$type} }) {
                @{ $val->{used_by} } = map $cache{$_} || "!!$_!!",
                  @{ $val->{used_by} };
                push @val, $val;
            }
        }

        $type = 'modules' if $type eq 'module';
        $self->{info}{$type} = \@val;
    }
}

sub get_files {
    my $self = shift;
    return $self->{info};
}

# scan_deps_runtime utility functions

sub _compile {
    my ($perl, $file, $inchash, $dl_shared_objects, $incarray) = @_;

    my $fname = File::Temp::mktemp("$file.XXXXXX");
    my $fhin  = FileHandle->new($file) or die "Couldn't open $file\n";
    my $fhout = FileHandle->new("> $fname") or die "Couldn't open $fname\n";

    my $line = do { local $/; <$fhin> };
    $line =~ s/use Module::ScanDeps::DataFeed.*?\n//sg;
    $line =~ s/^(.*?)((?:[\r\n]+__(?:DATA|END)__[\r\n]+)|$)/
use Module::ScanDeps::DataFeed '$fname.out';
sub {
$1
}
$2/s;
    $fhout->print($line);
    $fhout->close;
    $fhin->close;

    system($perl, $fname);

    _extract_info("$fname.out", $inchash, $dl_shared_objects, $incarray);
    unlink("$fname");
    unlink("$fname.out");
}

sub _execute {
    my ($perl, $file, $inchash, $dl_shared_objects, $incarray, $firstflag) = @_;

    $DB::single = $DB::single = 1;

    my $fname = _abs_path(File::Temp::mktemp("$file.XXXXXX"));
    my $fhin  = FileHandle->new($file) or die "Couldn't open $file";
    my $fhout = FileHandle->new("> $fname") or die "Couldn't open $fname";

    my $line = do { local $/; <$fhin> };
    $line =~ s/use Module::ScanDeps::DataFeed.*?\n//sg;
    $line = "use Module::ScanDeps::DataFeed '$fname.out';\n" . $line;
    $fhout->print($line);
    $fhout->close;
    $fhin->close;

    File::Path::rmtree( ['_Inline'], 0, 1); # XXX hack
    system($perl, $fname) == 0 or die "SYSTEM ERROR in executing $file: $?";

    _extract_info("$fname.out", $inchash, $dl_shared_objects, $incarray);
    unlink("$fname");
    unlink("$fname.out");
}

sub _make_rv {
    my ($inchash, $dl_shared_objects, $inc_array) = @_;

    my $rv = {};
    my @newinc = map(quotemeta($_), @$inc_array);
    my $inc = join('|', sort { length($b) <=> length($a) } @newinc);

    my $key;
    foreach $key (keys(%$inchash)) {
        my $newkey = $key;
        $newkey =~ s"^(?:(?:$inc)/?)""sg if ($newkey =~ m"^/");

        $rv->{$newkey} = {
            'used_by' => [],
            'file'    => $inchash->{$key},
            'type'    => _gettype($inchash->{$key}),
            'key'     => $key
        };
    }

    my $dl_file;
    foreach $dl_file (@$dl_shared_objects) {
        my $key = $dl_file;
        $key =~ s"^(?:(?:$inc)/?)""s;

        $rv->{$key} = {
            'used_by' => [],
            'file'    => $dl_file,
            'type'    => 'shared',
            'key'     => $key
        };
    }

    return $rv;
}

sub _extract_info {
    my ($fname, $inchash, $dl_shared_objects, $incarray) = @_;

    use vars qw(%inchash @dl_shared_objects @incarray);
    my $fh = FileHandle->new($fname) or die "Couldn't open $fname";
    my $line = do { local $/; <$fh> };
    $fh->close;

    eval $line;

    $inchash->{$_} = $inchash{$_} for keys %inchash;
    @$dl_shared_objects = @dl_shared_objects;
    @$incarray          = @incarray;
}

sub _gettype {
    my $name = shift;
    my $dlext = quotemeta(dl_ext());

    return 'autoload' if $name =~ /(?:\.ix|\.al|\.bs)$/;
    return 'module'   if $name =~ /\.pm$/;
    return 'shared'   if $name =~ /\.$dlext$/;
    return 'data';
}

sub _merge_rv {
    my ($rv_sub, $rv) = @_;

    my $key;
    foreach $key (keys(%$rv_sub)) {
        my %mark;
        if ($rv->{$key} and _not_dup($key, $rv, $rv_sub)) {
            warn "different modules for file: $key: were found" .
                 "(using the version) after the '=>': ".
                 "$rv->{$key}{file} => $rv_sub->{$key}{file}\n";

            $rv->{$key}{used_by} = [
                grep (!$mark{$_}++,
                    @{ $rv->{$key}{used_by} },
                    @{ $rv_sub->{$key}{used_by} })
            ];
            @{ $rv->{$key}{used_by} } = grep length, @{ $rv->{$key}{used_by} };
            $rv->{$key}{file} = $rv_sub->{$key}{file};
        }
        elsif ($rv->{$key}) {
            $rv->{$key}{used_by} = [
                grep (!$mark{$_}++,
                    @{ $rv->{$key}{used_by} },
                    @{ $rv_sub->{$key}{used_by} })
            ];
            @{ $rv->{$key}{used_by} } = grep length, @{ $rv->{$key}{used_by} };
        }
        else {
            $rv->{$key} = {
                used_by => [ @{ $rv_sub->{$key}{used_by} } ],
                file    => $rv_sub->{$key}{file},
                key     => $rv_sub->{$key}{key},
                type    => $rv_sub->{$key}{type}
            };

            @{ $rv->{$key}{used_by} } = grep length, @{ $rv->{$key}{used_by} };
        }
    }
}

sub _not_dup {
    my ($key, $rv1, $rv2) = @_;
    (_abs_path($rv1->{$key}{file}) ne _abs_path($rv2->{$key}{file}));
}

sub _abs_path {
    return join(
        '/',
        Cwd::abs_path(File::Basename::dirname($_[0])),
        File::Basename::basename($_[0]),
    );
}

1;

__END__


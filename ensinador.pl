#!/opt/perl-5.20.0/bin/perl 
# use strict;
# use warnings;
use CWB::CQP;
use POSIX;
use CGI qw/:standard/;
use Data::Dumper;
use List::Util qw/shuffle/;
use File::Slurp qw/slurp/;
use PHP::Include;
use URI::Escape;
use JSON;
our $JQUERY = '/ensinador/jquery.js';
our $DEBUG = 0;
our $LOGFILE = 'ensinador.log';

$Data::Dumper::Indent = 0;

our %identif_corpus;
require "/var/www/cgi-bin/biblioteca_corpora.pl";

include_php_vars("/var/www/html/acesso/var_corpora.php" );
#line 24
# put this line number in the line above

POSIX::setlocale( &POSIX::LC_ALL, "pt_PT" );
use locale;
our $VAR1;

if (param("gonetoselection") || param("addtitle") ||
    param("download_s") || param("download_e") ||
    param("random") || param('show') || param('hide')) {
    if (param('show')) {
        show_selection(1);
    } elsif (param('hide')) {
        show_selection(0);
    } else {
        my $status = param("status") || 0;
        show_selection(0);
    }
} elsif (param("query")) {
    print header;
    concordancias();
} else {
    my $corpus = param("corpus");

    $corpus = "CHAVE" if not($corpus) and not(exists $nomes_cqp{$corpus});

    print header;
    print start_html( -title => "Ensinador",
                      -style => { -code => css() },
                      -script => [
                                  { -language => 'JavaScript',
                                    -src => $JQUERY },
                                  { -language => 'JavaScript',
                                    -code => JS() },
                                 ]);
    print my_header();


    print '<div id="contents">';
    print formulario("Procurar");
    print p({-style=>"width: 60%; margin-left: auto; margin-right: auto; clear: both"},
            "O Ensinador é um sistema de criação de exercícios gramaticais sobre os corpos AC/DC, descrito em ",
            a({-href=>"http://www.linguateca.pt/documentos/index.html#1307718928"},
        	"Simões &amp; Santos (2011)"), ". Veja alguns exemplos de comandos e de exercícios ", a({-href=>"http://www.linguateca.pt/ensinador/ensinador_exemplos.html"}, "nesta página"), ".");
}

print <<EOH;
<hr>
<address>

<a href="http://www.linguateca.pt/cgi-bin/correio/FormularioCorreio.pl?pagina=dinis2//html/acesso/ensinador/&servico=Ensinador">Coment&aacute;rios, sugest&otilde;es e perguntas sobre o Ensinador</a>
</address>
</div>
EOH
print end_html;
exit 0;

sub show_selection {
    my $status = shift;

    $status = 1 if param("download_s");

    my $selected_corpus = param("corpus");
    my $corpus_details  = $identif_corpus{$selected_corpus};
    my $uni_basica      = param('basico')  || "s";
    my $climit          = param("maxres")  || 100;
    my $context         = param("context") || "1,1";

    my $id_doc          = param('ps')      || "p";
    my $saved           = param('saved') ? from_json(uri_unescape(param('saved'))) : {};
    my $maintitle       = param("maintitle") || "";
    my $download = param("download_s") || param("download_e") || 0;

    my $filename = $maintitle || "default";
    $filename =~ tr{áéíóúàèìòùãõâêîôûçÁÉÍÓÚÀÈÌÒÙÃÕÂÊÎÔÛÇ }
                   {aeiouaeiouaoaeioucAEIOUAEIOUAOAEIOUC_};

    if ($status) {
        print header(-content_disposition => "inline; filename=${filename}_solucao.html");
    } else {
        print header(-content_disposition => "inline; filename=$filename.html");
    }

    print start_html( -title => "Ensinador",
                      -style => { -code => css() },
                      -script => [
                                  { -language => 'JavaScript',
                                    -src => $JQUERY },
                                  { -language => 'JavaScript',
                                    -code => JS() },
                                 ]);

    print my_header() unless $download;

    print '<div class="results">';

    print h2($maintitle) if $maintitle;

    print start_form(-id => 'DaForm') unless $download;

    $DEBUG && print pre("Chosen concs: ", param("conc") || "nicles");

    if (param("conc")) {
        my $title = param("title");

        my $ip = $ENV{REMOTE_ADDR};

        ## Log Things!
        my $log = "--[".scalar(localtime)."]".("-" x 52);
        $log .= "\n".param("query")." :::: $selected_corpus :::: $title :::: Contexto: $context :::: IP: $ip\n";

        $total = param("hits");

        my @concordances;
        @concordances = param("conc");
        @concordances = map { eval uri_unescape($_)} @concordances;

        $log .= "seleccionadas ". scalar(@concordances). " de um total de $total\n";

        $log .= sprintf("%s << %s >> %s :: %s\n",
                        $_->{hit}{left},
                        join(" ", @{$_->{hit}{match}}),
                        $_->{hit}{right},
                        $_->{anot}) for (@concordances);
        @concordances = map { +{ iddoc => $id_doc,
                                 unbas => $uni_basica,
                                 corpo => $selected_corpus,
                                 conc  => $_ } } @concordances;
        push @{$saved->{$title}} =>  @concordances;

        if (open LOG, ">>", $LOGFILE) {
            print LOG $log;
            close LOG;
        }
    }

    $DEBUG && print pre(Dumper($saved));

    for my $title (keys %$saved) {
        if ($download) {
            print h3($title);
        } else {
            print div(textfield({-value => $title,
                                 -readonly => 1,
                                 -onfocus => q{edit($(this));}})),
        }
        print "<ol>\n";

        @{$saved->{$title}} = param("random") ? shuffle @{$saved->{$title}} : @{$saved->{$title}};

        my @hits = @{$saved->{$title}};
        for my $hit (@hits) {
            my $corpus = $hit->{corpo};
            my $iddoc  = $hit->{iddoc};
            my $unbas  = $hit->{unbas};
            my $anot   = $hit->{anot};
            print li(format_saved_data({show=>$status}, $hit->{conc}));
        }
        print "</ol>\n";
    }

    unless($download) {
        print hidden(-name => 'status', -value => $status,        -override => 1);
        print hidden( { -id => "saved", -name => "saved",
                        -value => uri_escape(to_json($saved)), -override => 1 } );

        print "<div class='box' style='text-align: center'>\n";

        print "<div style='float: right'>";
        print b("Adicionar título: ",
                textfield(-class=>'submit_title', -name => 'maintitle', -size => 30),
                submit(-class => "self", -id => 'submit_title',
                       -name => "addtitle", -value => " OK "));
        print "</div>";

        print "<div style='float: left'>";
        print(($status) ?
              submit(-class=> 'self',
                     -name => "hide",
                     -value => " Ver Enunciado ")
              :
              submit(-class => 'self',
                     -name => "show",
                     -value => " Ver Solução "));
        print "&nbsp;&nbsp;",
          submit(-class => "self", -name => "random", -value => " Aleatorizar ");
        print "</div>";

        print b("Descarregar: ",
                submit(-id => "download_e", -name => "download_e", -value => " enunciado "),
                submit(-id => "download_s", -name => "download_s", -value => " solução "));

        print "</div><div class='box'>\n";
        print formulario("Adicionar");
        print "<br style='clear: both'>\n";
        print "</div>\n";
        print end_form;
    }
}

sub my_cqp {
    my ($selected_corpus, $iddoc, $uni_basica, $context) = @_;

    my $CQP = CWB::CQP->new("-r /home/registo");
    error("cqp") unless $CQP;
    $CQP->set_error_handler( sub { error("" => @_); } );

    $CQP->exec($selected_corpus);
    $CQP->exec("show -cpos;");
    $CQP->exec(q{set LeftKWICDelim  "[% ";});
    $CQP->exec(q{set RightKWICDelim  " %]";});

    $CQP->exec("set ps $iddoc;");
    $CQP->exec("set c 1 $uni_basica;");
    $CQP->exec("set lc $context->[0] $uni_basica;");
    $CQP->exec("set rc $context->[1] $uni_basica;");

    return $CQP;
}

sub concordancias {
    error("no corpus")     if !param("corpus") || !param("query");
    error("invalid query") if param("query") =~ /;\s*cat\s/;

    my $lcontext        = param("lcontext") || 0;
    $lcontext = 2 if $lcontext > 2;

    my $rcontext        = param("rcontext") || 0;
    $rcontext = 2 if $rcontext > 2;

    my @context = ($lcontext + 1, $rcontext + 1);

    my $selected_corpus = param("corpus");
    my $corpus_details  = $identif_corpus{$selected_corpus};
    my $query_structure = guess_query(param("query"));
    error("syntax") if not defined($query_structure);

    my $user_query      = sprintf("A = %s %s;",
                                  join(" ", @{$query_structure->{query}}),
                                  $query_structure->{within} || ""
                                 );

    my $uni_basica      = $basico{$selected_corpus}          || "s";
    my $iddoc           = $iddoc{$selected_corpus}           || "p";
    my $climit          = $desc_corpora{$selected_corpus}[3] || 100;
    my $saved           = param('saved')                     || '{}';

    print start_html( -title => "Ensinador",
                      -style => { -code => css() });

    my $CQP = my_cqp($selected_corpus, $iddoc, $uni_basica, \@context);
    my $attr = attributes($CQP, $selected_corpus, hash_form => 1);

    my %ignoring_attributes;
    for my $atlist (@{$query_structure->{attrs}}) {
        next unless $atlist;
        for my $at (@$atlist) {
            $ignoring_attributes{$at}++ unless exists $attr->{$at};
        }
        $atlist = [ grep { !exists($ignoring_attributes{$_}) } @$atlist ];
    }

    $DEBUG && print pre("Executed query: ",_protect($user_query));

    $CQP->exec($user_query);
    my ($size) = $CQP->exec("size A");

    my $msg;
    if ($size > $climit) {
        $CQP->exec("reduce A to $climit;");
        $msg = "$climit entradas aleatórias de um total de $size entradas.";
    } elsif ($size == 0) {
        $msg = undef;
    } else {
        $msg = "$size entradas.";
    }

    print my_header();

    my $total = $size > $climit ? $climit : $size;

    print '<div class="results">';
    print start_form;
    print hidden(query   => param("query"));
    print hidden(corpus  => $selected_corpus);
    print hidden(basico  => $uni_basica);
    print hidden(hits    => $total);
    print hidden(maxres  => $climit);
    print hidden(context => join(",", @context));
    print hidden(ps      => $iddoc);
    print p("Guardadas as escolhas anteriores.") unless $saved eq '{}';
    print hidden(saved   => $saved),"\n";
    print hidden(gonetoselection => 1)."\n";

    if (%ignoring_attributes) {
        printf p("A ignorar os atributos desconhecidos: %s"),
          join(", ", keys %ignoring_attributes);
    }

    if ($msg) {
        print h3(param("title")), h4("A procurar &ldquo;". html_quote(param("query")).
                                     "&rdquo; no corpus $corpus_details [$msg]");
        print hidden("title" => param("title"));
        my @pos     = $CQP->dump("A");
        my @matches = $CQP->exec("cat A;");
        my $annot  = get_annot($CQP, $query_structure->{attrs}, @pos);

        for my $a (@$annot) {
            $a = join(", ", map { join(" ", $_ ? @$_ : () )  }  @$a);
            $a =~ s/,\s+,/,/g;
            $a =~ s/^\s*,\s*//;
            $a =~ s/\s*,\s*$//;
        }

        my @ans = map {
            my $anot = shift @$annot || undef;
            format_conc($_, $selected_corpus, $iddoc, $anot, $query_structure->{show})
        } @matches;

        print p("Seleccione as concordâncias que deseja usar.&nbsp;&nbsp;&nbsp;", submit(" OK "));
        print join("\n",@ans);
        print p("Seleccione as concordâncias que deseja usar.&nbsp;&nbsp;&nbsp;", submit(" OK "));
    } else {
        print p("Nenhuma concordância encontrada. Carregue no botão para continuar!");
        print submit(-name => "noconc", -value => " Continuar ");
    }
    print end_form;

}

sub get_annot {
    my ($CQP, $anots, @pos)  = @_;

    my @ans;
    my $i = 0;
    for my $anot (@$anots) {
        if ($anot) {
            my $tot;
            $CQP->exec("show -word;");

            my @npos = map {
                $_ = [ @$_ ]; # clone
                $_->[0] = $_->[1] = $_->[0] + $i;
                $_->[2] = -1;  # in any case...
                $_
            } @pos;

            for my $a (@$anot) {
                $CQP->exec("show +$a;");
                $CQP->exec("set c 0;");
                $CQP->undump("B" => @npos);

                my @tans = map { s/^.*\[%\s*//; s/\s*%\]\s*$//; $_ } $CQP->exec("cat B;");
                $CQP->exec("show -$a;");

                my $j = 0;
                for (@tans) {
                    push @{$ans[$j][$i]} => $_;
                    ++$j;
                }
            }
        }
        $i++;
    }

    return \@ans;
}


sub guess_query {
    my $query = shift;
    return "" unless $query !~ /^\s*$/;
    $query =~ s/^\s+//;
    $query =~ s/\s+$//;
    $DEBUG && print "<pre>query was {$query}</pre>\n";
    $query = "[word=\"$query\"]" if ($query =~ /^[\|[:alpha:]]+$/);
    $DEBUG && print "<pre>query is {$query}</pre>\n";

    for ($query) {  # nao e' array, mas o codigo fica mais limpo...
        s/within\s+([0-9]+\s)*parte\s*/within 100/g;
        s/within\s+([0-9]+\s)*texto\s*/within 100/g;
        s/within\s+([0-9]+\s)*obra\s*/within 100/g;

        s/within\s+([0-9]+\s)*capitulo\s*/within 100/g;
        s/within\s+([0-9]+\s)*art\s*/within 100/g;
        s/within\s+[0-9]+\s+ext\s*/within ext/g;
        s/within\s+[0-9]+\s+p\s*/within p/g;
        s/within\s+[3-9]+\s+s\s*/within 3 s/g;
        s/within\s+[0-9][0-9]+\ss\s*/within 3 s/g;

        s/within\s+([0-9]+\s)*fala\s*/within fala/g;
        s/within\s+[3-9]+\s+u\s*/within 3 u/g;
        s/within\s+[0-9][0-9]+\su\s*/within 3 u/g;

        s/within\s+[3-9][0-9][0-9]+\s*$/within 100/g;
        s/within\s+[3-9][0-9][0-9]+\s*\;/within 100\;/g;
        s/within\s+[0-9][0-9][0-9][0-9]+\s*$/within 100/g;
        s/within\s+[0-9][0-9][0-9][0-9]+\s*\;/within 100\;/g;

        #s/(^| )"(\S+)"( |$)/${1}[word="$2"]$3/g;
    }

    my $within = "";
    $within = $1 if ($query =~ s/( within .*$)//);
    #print STDERR "--${query}--\n";

    my $res;
    $DEBUG && print pre("parser: ", _protect($query), "\n", _protect(Dumper($res)));

    ### PARSER

    ## Analisar o pedido e retirar os detalhes específicos à notação
    ## do ensinador.
    while ($query =~ s{^
                       (?:
                           ( <[^>]+> )
                       |   (?: "([^"]+)" )
                       |
                           (?:
                               ( (?: [a-z]+:)? \[  (?: [^\]"]+ | " [^"]+ " )*  \] )
                               ( (?: ~ | (?: \. [a-zA-Z_]* )+)   |  (?:[*+]|\{\d+(?:,\d+)?\})?  |  )
                           )
                       )
                       \s*
                  }{}gx) {

        ## 1, 2, e 3 fazem parte da sintaxe CWB
        ## 4 é a anotação (ponto seguido do atributo, ou atributo omisso)
        ##   ou símbolos de repetição (kleene et al)
        my ($q, $attr) = ($1 || $2 || $3, $4);
        if ($q =~ /^</) {
            push @{$res->{query}} => $q;
            push @{$res->{attrs}} => undef;
            push @{$res->{show}}  => 1;
        } elsif ($q !~ /^(?:[a-z]+:)?\[/) {
            push @{$res->{query}} => qq{[word="$q"]};
            push @{$res->{attrs}} => undef;
            push @{$res->{show}}  => 1;
        } else {
            if ($attr =~ /[+*{]/) {
                $q = $q . $attr;
                $attr = "";
                push @{$res->{show}}  => -1;
            } elsif ($attr =~ s/^~//) {
                push @{$res->{show}}  => 0;
            } else {
                push @{$res->{show}}  => 1;
            }
            $attr =~ s/^\.//;
            push @{$res->{query}} => $q;
            push @{$res->{attrs}} => $attr ? [ split /\./ => $attr ] : undef;
        }

        $DEBUG && print pre("parser: ", _protect($query), "\n", _protect(Dumper($res)));
    }

    $query =~ s/^\s*$//;
    if ($query) {
        return undef;
    } else {
        $res->{within} = $within if $within;
        return $res;
    }
}

sub error {
    my $type = shift;
    if ($type eq "cqp") {
        print p("Erro ao iniciar o serviço CQP.");
        print p("Error starting service CQP.");
    } elsif ($type eq "invalid query") {
        print p("Pesquisa inválida.");
        print p("Invalid CQP query.");
    } elsif ($type eq "no corpus") {
        print p("Tentativa ilegal de aceder ao Ensinador.");
        print p("Illegal attempt to access Ensinador.");
    } elsif ($type eq "syntax") {
        print p("A sua expressão de pesquisa não está sintaticamente correta.");
    } else {
        print p("Erro! Error!"), pre(join("\n", @_));
    }
    exit 1;
}

sub format_saved_data {
    my ($ops, $data) = @_;
    my $line;

    $line = join(" ", $data->{hit}{left},
                 format_field($data->{hit}{match}, $data->{show}, $ops->{show}),
                 $data->{hit}{right});

    if (!$ops->{show}) {
        $line .= "   <span>$data->{anot}</span>"
    }

    $line = div({-class=>"o"}, $line);
    return $line;
}

sub trata {
    my $line = shift;
    for ($line) {
        s# ([.,:;?!\)](?:[^/]|$))#$1#g;

        # a restrição à barra é para quando mostrar o valor de
        # algum atributo, não juntar a pontuação
        s/\( /(/g;
        s/ »/»/g;
        s/« /«/g;
    }
    return $line;
}

sub format_conc {
    my ($line, $corpus, $iddoc, $anot, $show) = @_;

    for ($line) {
        s/<$iddoc([^>]+?)>/<i>$1<\/i>/;
        s!docid=!!;

        s#([-A-Z])<([^/])#$1&lt\;$2#g; # para tratar de func SUBJ< mas evitar PRED</strong
        s/<([-A-Z])/&lt\;$1/g;         # para tratar de func <PRED
        s/&lt;BR/<BR/g;                # para deixar os BRs
        s#<(/*[ps]>)#&lt\;$1#g;        # para tratar de <s> </s> <p> </p>
    }

    $line =~ /^ (.*) \[% \s* (.*) %\] (.*) $/x;
    my $data = {
                hit => { left => trata($1),
                         right => trata($3),
                         match => [split /\s+/, $2],
                       },
                show => $show,
                anot => $anot ? span("($anot)") : ""
               };

    my $match = format_field($data->{hit}{match}, $show, 1);

    $DEBUG && print pre(Dumper($data->{hit}{match}), Dumper($show), "obtained: $match");

    $line = join(" ", $data->{hit}{left}, $match, $data->{hit}{right}, $data->{anot});

    my $ddata = uri_escape(Dumper($data));
    $line = qq{<label><input type='checkbox' name='conc' value="$ddata"/>$line</label>};
    $line = div({-class=>"m"}, $line);
    return $line;
}

sub format_field {
    my ($words, $show, $flag) = @_;
    my $i = 0;
    my $out;
    my $found = 0;
    while (!$found && defined($words->[$i])) {
        if ($show->[$i] == 1) {
            if ($flag) {
                $out .= "<span class='c'>" . $words->[$i] . "</span> "
            } else {
                $out .= "_________"
            }
        } elsif ($show->[$i] == -1) {
            $found = 1;
        } else {
            $out .= "$words->[$i] "
        }
        ++$i;
    }

    $DEBUG && print "<pre>prefix: $out</pre>";

    my $left = $i;
    my $suffix;

    $i = -1;
    ## lado direito
    if ($found) {
        $found = 0;
        while (!$found && defined($words->[$i])) {
            if ($show->[$i] == 1) {
                if ($flag) {
                    $suffix = " <span class='c'>" . $words->[$i] . "</span>" . $suffix;
                } else {
                    $suffix = "_________" . $suffix;
                }
            } elsif ($show->[$i] == -1) {
                $found = 1;
            } else {
                $suffix = " $words->[$i]" . $suffix;
            }
            $i--;
        }
    }

    $DEBUG && print "<pre>suffix: $suffix</pre>";

    if ($found) {
        my $msize = scalar(@$words);

        $left--;
        $msize = $msize - $left + $i + 2;

        while ($msize > 0) {
            $out .= "$words->[$left] ";
            $left++;
            $msize--;
        }

        $out .= $suffix;
    } else {
        $out .= $suffix if $suffix;
    }

    return trata($out);
}


sub html_quote {
    my $str = shift || "";
    for ($str) {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
    }
    return $str;
}


sub attributes {
    my ($cqp, $cp, %ops) = @_;
    $cqp->exec(uc $cp);

    my @attributes = $cqp->exec("show cd;");
    my $attributes;
    for (@attributes) {
        my @line = split /\t/;
        if ($ops{hash_form}) {
            $attributes->{$line[1]} = $1 if $line[0] =~ /([ps])-Att/;
        } else {
            push @{$attributes->{p}}, $line[1] if $line[0] =~ /p-Att/;
            push @{$attributes->{s}}, $line[1] if $line[0] =~ /s-Att/;
        }
    }
    return $attributes;
}


sub css {
    return <<EOCSS
  body { font-family: times; }
  #contents { margin: 20px; }
  .box { margin: 5px; padding: 10px; border: dotted 1px #aaa; }
  body { margin: 0px; padding: 0px; }
  form { margin: 10px; }
  .c { font-weight: bold; }
  .u { text-decoration: underline; }
  .m { margin: 5px; }
  .o { margin: 5px; }
  .results { margin: 10px; }
  .m:hover { background-color: #defede; }
  #header  { margin: 0px; background-color: #dedede; padding: 5px; margin-bottom: 15px;
             border-bottom: solid 1px #000000; }
  input[type='text'][readonly] { width: auto; border: none; font-size: 15pt; font-weight: bold; }
  input[type='text'] { border: solid 1px #777; padding: 2px;}
  input[type='text']:hover { background-color: #efefef; }
  input[type='text']:focus { background-color: #efefef; }
  h2 { text-align: center; }
EOCSS
}

sub JS {
    return << 'EOJS';
  function edit(element) {
      var oldVal = element.val();
      element.removeAttr("readonly");
      element.change( function () {
         element.attr("readonly", 1);
         var saved = JSON.parse(unescape($("#saved").val()));
         saved[element.val()] = JSON.parse(JSON.stringify(saved[oldVal]));
         delete saved[oldVal];
         $("#saved").val(escape(JSON.stringify(saved)));
      } );
  }

  $(document).ready(function() {

     $('.self').click( function() {
         $('#DaForm').attr('target', '_self');
         $(this).submit();
     });
     $('#download_e').click( function() {
         $('#DaForm').attr('target', '_blank');
         $(this).submit();
     });
     $('#download_s').click( function() {
         $('#DaForm').attr('target', '_blank');
         $(this).submit();
     });

     $('.default').keypress(function(event) {
        if (event.which == '13') {
             $('#default').click();
        }});

     $('.submit_title').keypress(function(event) {
        if (event.which == '13') {
             $('#submit_title').click();
        }});

     $('#corpus').change( function() {
         var url = "/ensinador/sobre/index.pl/" + $('#corpus').val();
         $('#info').load(url);
     } );

     $('#corpus').change();

   });
EOJS
}

sub _protect {
    my $a = shift;
    $a =~ s/&/&amp;/g;
    $a =~ s/</&lt;/g;
    $a =~ s/>/&gt;/g;
    return $a;
}

sub formulario {
    my $action = shift;
    join("",
         div({-id=>"info",
              -style=>"width: 50%; float: right; padding-left: 20px; border-left: dotted 1px #ddd;" },""),
         start_form,
         table(
               Tr(td("Procurar"),
                  td({-colspan=>"2"}, textfield(-name => "query", -size=>"30"))),
               Tr(td("Secção"),
                  td({-colspan=>"2"}, textfield(-name => "title", -size=>"30"))),
               Tr(td("Corpo"),
                  td({-colspan=>"2"}, popup_menu(-name    => 'corpus',
                                                 -id      => 'corpus',
                                                 -values  => [sort keys %corpora],
                                                 -default => 'CHAVE' ))),
               Tr(td({-rowspan=>2},"Contexto"),
                  td("&nbsp;esquerdo"),
                  td(textfield({-name => 'lcontext', -value => 0, -size=>"2",
                                -title => "Valores superiores a 2 serão truncados."}), "frases")),
               Tr(td("&nbsp;direito"),
                  td(textfield({-name => 'rcontext', -value => 0, -size=>"2",
                                -title => "Valores superiores a 2 serão truncados."}), "frases"))),
         p(submit(-id => 'default', -class=> 'self', -name=>"accao", -value=>" $action ")),
         end_form);
}

sub my_header {
    div({-id => 'header' },
        div({-style => "float: right; text-align: right;"},
            a({-href=>"http://www.linguateca.pt/", -target=>"_top"}, 'Linguateca'),
            br,
            a({-href=>"http://www.linguateca.pt/ACDC/", -target=>"_top"}, 'AC/DC'),
            br,
            a({-href=>"/ensinador/" }, "Reiniciar Ensinador"),
           ),
        h1('Ensinador'));
}

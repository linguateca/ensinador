#!/opt/perl-5.20.0/bin/perl

use strict;
use warnings;

use PHP::Include;
use CGI qw.:standard.;
use JSON;

include_php_vars("/var/www/html/acesso/var_corpora.php");
#line 12
# put above the line number for this line, for decent error reporting.

print header( -charset => 'iso-8859-1' );

my $path = $ENV{PATH_INFO};
$path =~ s{/}{}g;

if (exists($corpora{$path})) {
    show_info($path);
} else {
    print "corpus desconhecido";
}

sub show_info {
    my $corpus = shift;

    my ($desc, $genre, $langs) = @{ $desc_corpora{$corpus} };
    my $fname = $corpora{$corpus};

    my ($unidades, $palavras, $frases, $paragrafos, $wTypes) = split /:/, $info_dim{$corpus};

    my $left = dl(dt({-style=>"font-weight: bold"},"Descrição"),
                  dd($desc),
                  dt({-style=>"font-weight: bold"},"Género"),
                  dd($genre),
                  dt({-style=>"font-weight: bold"},"Variantes"),
                  dd($langs));
    my $right = table(Tr(td("Unidades:"),
                         td({-style=>"text-align: right"}, $unidades)),
                      Tr(td("Palavras:"),
                         td({-style=>"text-align: right"}, $palavras)),
                      Tr(td("Frases:"),
                         td({-style=>"text-align: right"}, $frases)),
                      Tr(td("Parágrafos:"),
                         td({-style=>"text-align: right"}, $paragrafos)),
                      Tr(td("Tipos:"),
                         td({-style=>"text-align: right"}, $wTypes)));
    print div(h3("Corpo $fname"),
              table(Tr(td({-style=>"padding-right: 20px;"},$left),
                       td({-style=>"border: solid 2px #AAA; background-color: #EFEFEF;"},
                          $right))));
}

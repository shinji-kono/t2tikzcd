#!/usr/bin/perl -w

my $version  = "0.12";

use strict;
use utf8;
use open qw(:std :utf8); # input/output default encoding will be UTF-8, it looks like default

use Unicode::GCString;
use Unicode::Normalize;
use Getopt::Std;
our($opt_m, $opt_b, $opt_s);

getopts('ndhs:'); 

my @lines = <>;
my $nodes;
my $edges;
my $vedges;
my $prev;
my $conv = $opt_m;    # 1 to convert math symbol
my $nobend = $opt_b;  # 1 to bend bidirectional arrow
my $svg = $opt_s;     # 1 to generate SVG instead of LaTeX

&detect_horizotal_line;

&detect_vertical_line;

# find nodes and edges 

my $i = 0;
print "\\begin{tikzcd}\n";
for my $node (@$nodes) {
    my $flag = 0;
    for my $n (@$node) {
        &find_v_arrow($n);
        $flag |= &print_node($n);
    }
    print "\\mbox{} \\\\\n" if ($flag);
    $i++;
}
print "\\end{tikzcd}\n";

sub detect_horizotal_line
{
    # detect horizontal line and node
    my $i = 0;
    $prev = '';
    for my $line1 (@lines) {
        $line1 =~ s/^\%+//;
        my $line = $line1;
        my $x = 0;
        chop($line);
        my $prevarrow = 0;
        while($line) {
            if ($line =~ s/^(\s*)([^-\s\<\>]+)(\s*)(\<*)(\-+)(\>*)//) { # <----->
                my $e = {x=>$x+&unilength($1)+&unilength($2)+&unilength($3),y=>$i,len=>&unilength($4)+&unilength($5)+&unilength($6)};
                $e->{dir} .= "left " if ($4);
                $e->{dir} .= "right " if ($6);
                push(@{$edges->[$i]},$e);
                push(@{$nodes->[$i]},{x=>$x+&unilength($1),y=>$i,len=>&unilength($2),node=>$2,right=>[$e]});
                $e->{ulabel}   = [&find_h_label($e,$prev)];
                $e->{dlabel}   = [&find_h_label($e,$lines[$i+1])];
                $prevarrow = $e;
                $x += &unilength($&);
            } elsif ($line =~ s/^\s+[\^\|v]//) {
                $x += &unilength($&);
                $prevarrow = 0;
            } elsif ($line =~ s/^(\s*)([^\s]+)\s*//) {
                my $n = {x=>$x+&unilength($1),y=>$i,len=>&unilength($2),node=>$2};
                push(@{$nodes->[$i]},$n);
                if ($prevarrow) { 
                    $n->{left} = $prevarrow;
                }
                $prevarrow = 0;
                $x += &unilength($&);
            } elsif ($line =~ s/.//) {
            }
        }
        $prev = $lines[$i];
        $i++;
    }
}

sub find_h_label {
    my ($edge,$line) = @_;
    return "" if (&unilength($line) < $edge->{x});
    my $sub = substr($line,$edge->{x},$edge->{len});
    return $1 if ($sub =~ /\s*(\S+)\s*/);
    return "";
}

sub detect_vertical_line {
    my $i = 0;
    my $prev = '';
    my %v;
    for my $line1 (@lines) {
        $line1 =~ s/^\%+//;
        my $line = $line1;
        my $x = 0;
        while($line =~ s/^([^|]*?)([^\s|]*)[v\^]*\|[\^v]*([^\|\s]*)//) {
            # label contains ^v next to bar is not allowed.
            my $xx = $x+&unilength($1)+&unilength($2);
            if (defined $v{$xx}) {
                my $pv = $v{$xx};
                if ($pv->{ylast}!=$i-1) {
                   # close previous one
                   push(@$vedges, $pv);
                   $pv = {x=>$xx,y=>$i};
                }
                &add_vlabel($pv,$2,$3);
                $pv->{ylast} = $i;
                $v{$xx} = $pv;
            } else { # start new vertical line
                $v{$xx} = {x=>$xx,y=>$i,ylast=>$i};
                &add_vlabel($v{$xx},$2,$3);
            }
            $x += &unilength($&);
        }
        $prev = $lines[$i];
        $i++;
    }
    # close all vertical edge
    for my $xx (keys %v) {
       push(@$vedges, $v{$xx});
    }
    # find edge
    for my $e (@{$vedges}) {
        &find_v_heads('^',$e,$lines[$e->{y}-1]);
        &find_v_heads('v',$e,$lines[$e->{ylast}+1]);
#        &PP($e);
    }
}

sub add_vlabel {
    my ($pv, $rlabel ,$llabel) = @_;
    $rlabel = '' if ($rlabel =~ /^\s*[\^v]\s*$/);
    $llabel = '' if ($llabel =~ /^\s*[\^v]\s*$/);
    push(@{$pv->{rlabel}},$rlabel) if ($rlabel);
    push(@{$pv->{llabel}},$llabel) if ($llabel);
}

sub find_v_heads {
    my ($h,$edge,$line) = @_;
    return if (&unilength($line) < $edge->{x});
    my $head = substr($line,$edge->{x},1);
    if ($head eq $h) {
       if ($h eq '^') {
           $edge->{dir} .= 'up '; $edge->{y} --;
       } elsif ($h eq 'v') {
           $edge->{dir} .= 'down '; $edge->{ylast} ++;
       }
    }
}

# seerch arrows on or under the edge
sub find_v_arrow {
    my ($node) = @_;
    my (@edge);
#    &PP($node);
    for my $v (@$vedges) {
#        &PP($v);
        next if ($node->{y} != $v->{y}-1 && $node->{y} != $v->{ylast}+1);
#        print " y match ";
        if ($node->{x} <= $v->{x} && $v->{x} <= $node->{x}+$node->{len}) {
#            print " x match ";
            $v->{dir} = '' if (! $v->{dir});
            if ($v->{y}-1 == $node->{y}) { #  && $v->{dir} =~ /down/) {
                push(@{$node->{down}},$v);
            } 
            if ($v->{ylast}+1 == $node->{y}) { #  && $v->{dir} =~ /up/) {
                push(@{$node->{up}},$v);
            }
        }
    }
}

sub print_node {
    my ($node) = @_;
    my $label;
    my $arrow;
    if ($node->{node} eq "_" || $node->{right} || $node->{left} || $node->{up} || $node->{down} ) {
        if ($node->{node}) {
            if ($node->{node} eq "_" ) {
                print "\\mbox{} ";
            } else {
                &Print( $node->{node} );
            }
        } else {
            return 0;
        }
        for $arrow (@{$node->{right}})  {
            my $dir = $arrow->{dir} =~ /left/ ? "[leftarrow]":"";
            if ($arrow->{ulabel} && ($label = join(" ",@{$arrow->{ulabel}}))) {
                $dir = &check_bend($node, "right", "bend left",$dir);
                &Print( " \\arrow".$dir."{r}{$label}" );  
            } elsif ($arrow->{dlabel} && ($label = join(" ",@{$arrow->{dlabel}}))) {
                $dir = &check_bend($node, "right", "bend right",$dir);
                &Print( " \\arrow".$dir."{r}[swap]{$label}")  ;
            } else {
                &Print( " \\arrow".$dir."{r}{}"  );
            }
        }
        for $arrow (@{$node->{up}})  {
            next if ($arrow->{dir} !~ /up/);
            if ($arrow->{llabel} && ($label = join(" ",@{$arrow->{llabel}}))) {
                my $bend = &check_bend($node,"up", "bend right","");
                &Print( " \\arrow${bend}{u}[swap]{$label}"  );
            } elsif ($arrow->{rlabel} && ($label = join(" ",@{$arrow->{rlabel}}))) {
                my $bend = &check_bend($node, "up", "bend left","");
                &Print( " \\arrow${bend}{u}{$label}"  );
            } else {
                print " \\arrow{u}{}"  
            }
        }
        for $arrow (@{$node->{down}})  {
            next if ($arrow->{dir} !~ /down/);
            if ($arrow->{llabel} && ($label = join(" ",@{$arrow->{llabel}}))) {
                my $bend = check_bend($node, "down", "bend left","");
                &Print( " \\arrow${bend}{d}{$label}"  );
            } elsif ($arrow->{rlabel} && ($label = join(" ",@{$arrow->{rlabel}}))) {
                my $bend = check_bend($node, "down", "bend right","");
                &Print( " \\arrow${bend}{d}[swap]{$label}" ) ;
            } else {
                print " \\arrow{d}{}"  
            }
        }
        print " & ";
        return 1;
    } else {
        return 0;
    }
}

# If we have two arrows on a node, tikz-cd.sty makes these as one. Bending the arrows avoid these unification.
sub check_bend {
    my ($node,$dir,$bend,$opt) = @_;
    my $ans = '';
    return $opt if ($nobend);
    for my $arrow (@{$node->{$dir}}) {
        if ($dir eq "up") {
            if( $arrow->{dir} =~ /down/ ){ $ans = $bend ; last; }
        } elsif ($dir eq "down") {
            if( $arrow->{dir} =~ /up/ ){ $ans = $bend ; last; }
        } elsif ($dir eq "right") {
            if ($opt =~ /left/) {
                if( $dir = $arrow->{dir} =~ /right/ ){ $ans = $bend ; last; }
            } else {
                if( $dir = $arrow->{dir} =~ /left/ ){ $ans = $bend ; last; }
            }
        }
    }
    return $opt if ($ans eq "");
    if ($opt =~ /\]/) {
        $opt =~ s/\]/,$bend\]/;
        return $opt;
    }
    return "\[$bend\]";
}

sub PP {
    my ($v) = @_;
    print "\n";
    print " node:".$v->{node} if (defined $v->{node});
    print " x:".$v->{x} if (defined $v->{x});
    print " y:".$v->{y} if (defined $v->{y});
    print " ylast:".$v->{ylast} if (defined $v->{ylast});
    print " len:".$v->{len} if (defined $v->{len});
    my $label;
    if (defined $v->{ulabel} && ($label = join(" ",@{$v->{ulabel}}))) {
        print " u{$label}"  
    } 
    if (defined $v->{dlabel} && ($label = join(" ",@{$v->{dlabel}}))) {
        print " d{$label}"  
    }
    if (defined $v->{llabel} && ($label = join(" ",@{$v->{llabel}}))) {
        print " l{$label}"  
    }
    if (defined $v->{rlabel} && ($label = join(" ",@{$v->{rlabel}}))) {
        print " r{$label}"  
    }
}


sub unilength {
    my ($str) = @_;
    return 0 if (! defined $str);
    return Unicode::GCString->new($str)->columns;
}

sub Print {
    if ($conv) {
        print &convmath(@_);
        return;
    }
    print @_;
}

sub convmath {
    local($_) = @_;
#    my $dol = $mathmode ? '' : '$';
    my $dol = '';
    s/->/${dol}\\rightarrow{}${dol}/g;
    s/→/${dol}\\rightarrow{}${dol}/g;
    s/<-/${dol}\\leftarrow{}${dol}/g;
    s/←/${dol}\\leftarrow{}${dol}/g;
    s/<->/${dol}\\leftrightarrow{}${dol}/g;
    s/↔/${dol}\\leftrightarrow{}${dol}/g;
    s/=>/${dol}\\Rightarrow{}${dol}/g;
    s/⇒/${dol}\\Rightarrow{}${dol}/g;
    s/<=/${dol}\\{Leftarrow}${dol}/g;
    s/⇐/${dol}\\{Leftarrow}${dol}/g;
    s/<=>/${dol}\\Leftrightarrow{}${dol}/g;
    s/⇔/${dol}\\Leftrightarrow{}${dol}/g;
    s/○/${dol}\\circ{}${dol}/g;
    s/∇/${dol}\\nabla{}${dol}/g;
    s/□/${dol}\\Box{}${dol}/g;
    s/◇/${dol}\\Diamond{}${dol}/g;
    s/¬/${dol}\\neg{}${dol}/g;
    s/∀/${dol}\\forall{}${dol}/g;
    s/∃/${dol}\\exists{}${dol}/g;
    s/∂/${dol}\\partial{}${dol}/g;
    s/∩/${dol}\\cap{}${dol}/g;
    s/∪/${dol}\\cup{}${dol}/g;
    s/∨/${dol}\\vee{}${dol}/g;
    s/∧/${dol}\\wedge{}${dol}/g;
    s/∋/${dol}\\ni{}${dol}/g;
    s/∈/${dol}\\in{}${dol}/g;
    s/∞/${dol}\\infty{}${dol}/g;
    s/α/${dol}\\alpha{}${dol}/g;
    s/β/${dol}\\beta{}${dol}/g;
    s/Γ/${dol}\\Gamma{}${dol}/g;
    s/γ/${dol}\\gamma{}${dol}/g;
    s/Δ/${dol}\\Delta{}${dol}/g;
    s/δ/${dol}\\delta{}${dol}/g;
    s/∈/${dol}\\epsilon{}${dol}/g;
    s/ε/${dol}\\varepsilon{}${dol}/g;
    s/ζ/${dol}\\zeta{}${dol}/g;
    s/η/${dol}\\eta{}${dol}/g;
    s/Θ/${dol}\\Theta{}${dol}/g;
    s/θ/${dol}\\theta{}${dol}/g;
    # s//${dol}\\vartheta{}${dol}/g;
    s/ι/${dol}\\iota{}${dol}/g;
    s/Κ/${dol}\\kappa{}${dol}/g;
    s/κ/${dol}\\Lambda{}${dol}/g;
    s/λ/${dol}\\lambda{}${dol}/g;
    s/μ/${dol}\\mu{}${dol}/g;
    s/ν/${dol}\\nu{}${dol}/g;
    s/Χ/${dol}\\Xi{}${dol}/g;
    s/χ/${dol}\\xi{}${dol}/g;
    s/Π/${dol}\\Pi{}${dol}/g;
    s/π/${dol}\\pi{}${dol}/g;
    # s//${dol}\\varpi{}${dol}/g;
    s/ρ/${dol}\\rho{}${dol}/g;
    # s//${dol}\\varrho{}${dol}/g;
    s/Σ/${dol}\\Sigma{}${dol}/g;
    s/σ/${dol}\\sigma{}${dol}/g;
    # s//${dol}\\varsigma{}${dol}/g;
    s/τ/${dol}\\tau{}${dol}/g;
    s/Υ/${dol}\\Upsilon{}${dol}/g;
    s/υ/${dol}\\upsilon{}${dol}/g;
    s/Φ/${dol}\\Phi{}${dol}/g;
    s/φ/${dol}\\phi{}${dol}/g;
    # s//${dol}\\varphi{}${dol}/g;
    s/χ/${dol}\\chi{}${dol}/g;
    s/Ψ/${dol}\\Psi{}${dol}/g;
    s/ψ/${dol}\\psi{}${dol}/g;
    s/Ω/${dol}\\Omega{}${dol}/g;
    s/ω/${dol}\\omega{}${dol}/g;
    s/・/${dol}\\bullet{}${dol}/g;
#    s/Α/${dol}\\Alpha{}${dol}/g;
#    s/Β/${dol}\\Beta{}${dol}/g;
    return $_;
}

my $svg_header1 = << 'EOFEOF';
<?xml version="1.0"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
EOFEOF

sub svg_viewbox {
    my ($x,$y,$x1,$y1) = @_;
    my ($width,$height) = ($x1-$x,$y1-$y);
    print "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xl=\"http://www.w3.org/1999/xlink\" version=\"1.1\" viewBox=\"$x $y $x1 $y1\" width=\"${width}pt\" height=\"${height}pt\">\n";
}

my $svg_header2 = << 'EOFEOF';
<defs>
<marker orient="auto" overflow="visible" markerUnits="strokeWidth" id="FilledArrow_Marker" viewBox="-1 -4 10 8" markerWidth="10" markerHeight="8" color="black">
<g> <path d="M 8 0 L 0 -3 L 0 3 Z" fill="currentColor" stroke="currentColor" stroke-width="1"/> </g>
</marker>
</defs>
<g stroke="none" stroke-opacity="1" stroke-dasharray="none" fill="none" fill-opacity="1">
<title> Canvas 1</title>
<g>
<title> Layer 1</title>
EOFEOF

my $svg_footer = << 'EOFEOF';
</g>
</g>
</svg>
EOFEOF

# svg generation
#   this is a bad idea, since we cannot edit svg in visual. it is better to generate OmniGraffle format.
#
#  All position must be calcurated.
#
#
#              Tμ(d)                T^2(g)
#      T^2(d)<-----------T^2(T(d))<--------  T^2(c)
#      |                 |                    |
#      |                 |                    |
#  μ(d)|                 |μ(T(d))             |μ(c)
#      |                 |                    |
#      v        μ(d)     v           T(g)     v
#      T(d) <----------- T(T(d)) <---------- T(c)
#
#

sub svg_hline {
    my ($x,$y,$len,$dir,$otext,$btext) = @_;
    my $x1 = $x + $len;
    ($x,$x1) = ($x1,$x) if ($dir);
    print "<line x1=\"$x\" y1=\"$y\" x2=\"$x1\" y2=\"$y\" marker-end=\"url(#FilledArrow_Marker)\" stroke=\"black\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1\"/>\n";

}

sub svg_vline {
    my ($x,$y,$len,$dir,$ltext,$rtext) = @_;
    my $y1 = $y + $len;
    ($y,$y1) = ($y1,$y) if ($dir);
    print "<line x1=\"$x\" y1=\"$y\" x2=\"$x\" y2=\"$y1\" marker-end=\"url(#FilledArrow_Marker)\" stroke=\"black\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1\"/>\n";

}

sub svg_node {
    my ($x,$y,$text) = @_;
    print "<text transform=\"translate($x $y)\" fill=\"black\"> $text </text>\n";
}

sub print_svg
{
    my ($node) = @_;
    my $label;
    my $arrow;
    if ($node->{node} eq "_" || $node->{right} || $node->{left} || $node->{up} || $node->{down} ) {
        if ($node->{node}) {
            if ($node->{node} eq "_" ) {
                print "\\mbox{} ";
            } else {
                &Print( $node->{node} );
            }
        } else {
            return 0;
        }
        for $arrow (@{$node->{right}})  {
            my $dir = $arrow->{dir} =~ /left/ ? "[leftarrow]":"";
            if ($arrow->{ulabel} && ($label = join(" ",@{$arrow->{ulabel}}))) {
                $dir = &check_bend($node, "right", "bend left",$dir);
                &Print( " \\arrow".$dir."{r}{$label}" );  
            } elsif ($arrow->{dlabel} && ($label = join(" ",@{$arrow->{dlabel}}))) {
                $dir = &check_bend($node, "right", "bend right",$dir);
                &Print( " \\arrow".$dir."{r}[swap]{$label}")  ;
            } else {
                &Print( " \\arrow".$dir."{r}{}"  );
            }
        }
        for $arrow (@{$node->{up}})  {
            next if ($arrow->{dir} !~ /up/);
            if ($arrow->{llabel} && ($label = join(" ",@{$arrow->{llabel}}))) {
                my $bend = &check_bend($node,"up", "bend right","");
                &Print( " \\arrow${bend}{u}[swap]{$label}"  );
            } elsif ($arrow->{rlabel} && ($label = join(" ",@{$arrow->{rlabel}}))) {
                my $bend = &check_bend($node, "up", "bend left","");
                &Print( " \\arrow${bend}{u}{$label}"  );
            } else {
                print " \\arrow{u}{}"  
            }
        }
        for $arrow (@{$node->{down}})  {
            next if ($arrow->{dir} !~ /down/);
            if ($arrow->{llabel} && ($label = join(" ",@{$arrow->{llabel}}))) {
                my $bend = check_bend($node, "down", "bend left","");
                &Print( " \\arrow${bend}{d}{$label}"  );
            } elsif ($arrow->{rlabel} && ($label = join(" ",@{$arrow->{rlabel}}))) {
                my $bend = check_bend($node, "down", "bend right","");
                &Print( " \\arrow${bend}{d}[swap]{$label}" ) ;
            } else {
                print " \\arrow{d}{}"  
            }
        }
        print " & ";
        return 1;
    } else {
        return 0;
    }
}

=head1 NAME

t2tikzcd.pl -- Convert ASCII commutative diagram to tikzcd LaTeX command

=head1 AUTHORS

Shinji KONO <kono@ie.u-ryukyu.ac.jp>

=head1 SYNOPSIS

    perl t2tikzcd.pl category.txt

=head1 DESCRIPTION

You need
    \usepackage{tikz}
    \usepackage{tikz-cd}

example input 1

                 εFU(b)
     FUFU(b)  ------------> 1_A FU(b)
       |                     |
       |FUε(b)               |1_aε(b)
       |                     |
       v         ε(b)        v
     FU1_B(b) ------------> 1_B 1_B (b)

output should be

    \begin{tikzcd}
    FUFU(b) \arrow{r}{εFU(b)} \arrow{d}{FUε(b)} & 1_A \arrow{d}{1_aε(b)} & \mbox{} \\
    FU1_B(b) \arrow{r}{ε(b)} & 1_B & \mbox{} \\
    \end{tikzcd}

No diagonal arrows.

put single _ to keep absent node position.

           η(a)       
      a-----------> T(a) 
                    |   
                    |  
                    |φ 
                    | 
                    v  
      _             a  
                      
    \begin{tikzcd}
    a \arrow{r}{η(a)} & T(a) \arrow{d}{φ} & \mbox{} \\
    \mbox{}  & a & \mbox{} \\
    \end{tikzcd}

Labels have to be next to the horizontal or vertial arrow.

Too short arrow may results shorten label.

There is no automatic conversion for UTF8 chars. ε should be replaced by \varepsilon

You needs
    sudo cpan -i Unicode::GCString 

=cut



# t2tikzcd

Convert ASCII commutative diagram to tikzcd LaTeX command

# AUTHORS

Shinji KONO <kono@ie.u-ryukyu.ac.jp>

# SYNOPSIS

    perl t2tikzcd.pl category.txt

# DESCRIPTION

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


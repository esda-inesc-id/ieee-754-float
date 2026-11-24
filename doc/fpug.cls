% User guide class for the IEEE-754 floating-point units
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{fpug}[2026/11/24 IEEE-754 floating-point units user guide]
\LoadClass[twoside,a4paper,11pt,openany]{report}

\RequirePackage[T1]{fontenc}
\RequirePackage{helvet}
\renewcommand{\familydefault}{\sfdefault}
\RequirePackage[includehead,includefoot,a4paper,width=170mm,left=20mm,top=15mm,bottom=15mm,headheight=28pt]{geometry}
\RequirePackage{fancyhdr}
\RequirePackage{graphicx}
\RequirePackage[table]{xcolor}
\RequirePackage{array}
\RequirePackage{longtable}
\RequirePackage{booktabs}
\RequirePackage{amsmath}
\RequirePackage{enumitem}
\RequirePackage{float}
\RequirePackage{caption}
\RequirePackage{needspace}
\RequirePackage{etoolbox}
\RequirePackage{titlesec}
\RequirePackage{listings}
\RequirePackage{tikz}
\RequirePackage{tikz-timing}
\usetikzlibrary{positioning,arrows.meta,calc}
\RequirePackage[all]{nowidow}
\RequirePackage[hidelinks,bookmarksnumbered=true]{hyperref}

% Colors
\definecolor{ug-accent}{RGB}{0,150,136}
\definecolor{ug-head}{RGB}{178,236,226}
\definecolor{ug-block}{RGB}{226,245,241}
\definecolor{ug-code}{gray}{0.96}

% Paragraphs and page breaking
\setlength{\parindent}{0pt}
\setlength{\parskip}{0.6\baselineskip}
\widowpenalty=10000
\clubpenalty=10000
\brokenpenalty=10000
\setlength{\emergencystretch}{2em}
\raggedbottom
\setlist{nosep,topsep=2pt,leftmargin=*}
\captionsetup{font={small,bf},labelsep=colon,skip=6pt}
\setlength{\LTpre}{6pt}
\setlength{\LTpost}{6pt}
\renewcommand{\arraystretch}{1.15}

% Headings
\titleformat{\chapter}[hang]{\normalfont\huge\bfseries}{\thechapter}{0.6em}{}[{\color{ug-accent}\titlerule[1.2pt]}]
\titlespacing*{\chapter}{0pt}{0pt}{12pt}
\titleformat{\section}{\normalfont\Large\bfseries}{\thesection}{0.6em}{}
\titleformat{\subsection}{\normalfont\large\bfseries}{\thesubsection}{0.6em}{}
\titlespacing*{\section}{0pt}{12pt}{3pt}
\titlespacing*{\subsection}{0pt}{9pt}{2pt}
\setcounter{secnumdepth}{2}
\setcounter{tocdepth}{1}
\preto\section{\Needspace*{9\baselineskip}}
\preto\subsection{\Needspace*{6\baselineskip}}

% Header and footer
\newcommand{\ugtitle}{IEEE-754 Floating-Point Units}
\renewcommand{\chaptermark}[1]{\markboth{\thechapter.\ #1}{}}
\fancypagestyle{ug}{%
  \fancyhf{}%
  \fancyhead[RO,LE]{\textbf{\ugtitle}\\\textsc{\small User Guide}}%
  \fancyhead[LO,RE]{\small\nouppercase{\leftmark}}%
  \fancyfoot[LO,RE]{\small MIT License}%
  \fancyfoot[LE,RO]{\thepage}%
  \renewcommand{\headrulewidth}{.4pt}%
  \renewcommand{\footrulewidth}{.4pt}%
}
\fancypagestyle{plain}{%
  \fancyhf{}%
  \fancyhead[RO,LE]{\textbf{\ugtitle}\\\textsc{\small User Guide}}%
  \fancyfoot[LO,RE]{\small MIT License}%
  \fancyfoot[LE,RO]{\thepage}%
  \renewcommand{\headrulewidth}{.4pt}%
  \renewcommand{\footrulewidth}{.4pt}%
}
\pagestyle{ug}

% Code listings
\lstdefinelanguage{ugverilog}{
  morekeywords={module,endmodule,parameter,input,output,wire,reg,assign},
  sensitive=true, morecomment=[l]{//}
}
\lstdefinestyle{ugcode}{
  basicstyle=\ttfamily\small, columns=fixed, keepspaces=true,
  backgroundcolor=\color{ug-code}, frame=single, rulecolor=\color{black!25},
  xleftmargin=4pt, xrightmargin=4pt, aboveskip=6pt, belowskip=6pt,
  breaklines=false, showstringspaces=false, float=false
}
\lstnewenvironment{vcode}{\Needspace*{17\baselineskip}\lstset{style=ugcode,language=ugverilog,keywordstyle=\bfseries}}{}
\lstnewenvironment{shcode}{\Needspace*{4\baselineskip}\lstset{style=ugcode}}{}

% Tables: caption below, header repeated on each page
\newcommand{\ughead}[1]{\multicolumn{1}{|l|}{\cellcolor{ug-head}\bfseries #1}}
\newcommand{\ugheadr}[1]{\multicolumn{1}{l|}{\cellcolor{ug-head}\bfseries #1}}
\newlength{\ugcola}\newlength{\ugcolb}\newlength{\ugcolc}\newlength{\ugcold}

% {caption}{label}: name, default, description
\newenvironment{paramtable}[2]{%
  \Needspace*{7\baselineskip}%
  \setlength{\ugcola}{3.1cm}\setlength{\ugcolb}{2.9cm}%
  \setlength{\ugcolc}{\dimexpr\textwidth-\ugcola-\ugcolb-6\tabcolsep-4\arrayrulewidth-1pt\relax}%
  \small
  \begin{longtable}{|>{\ttfamily}p{\ugcola}|>{\ttfamily}p{\ugcolb}|>{\raggedright\arraybackslash}p{\ugcolc}|}
  \hline \ughead{Parameter} & \ugheadr{Default} & \ugheadr{Description} \\ \hline\hline \endfirsthead
  \hline \ughead{Parameter} & \ugheadr{Default} & \ugheadr{Description} \\ \hline\hline \endhead
  \hline \endfoot
  \hline \caption{#1}\label{#2} \endlastfoot
}{\end{longtable}}

% {caption}{label}: name, direction, width, description
\newenvironment{sigtable}[2]{%
  \Needspace*{7\baselineskip}%
  \setlength{\ugcola}{2.9cm}\setlength{\ugcolb}{1.6cm}\setlength{\ugcold}{2.9cm}%
  \setlength{\ugcolc}{\dimexpr\textwidth-\ugcola-\ugcolb-\ugcold-8\tabcolsep-5\arrayrulewidth-1pt\relax}%
  \small
  \begin{longtable}{|>{\ttfamily}p{\ugcola}|p{\ugcolb}|>{\ttfamily}p{\ugcold}|>{\raggedright\arraybackslash}p{\ugcolc}|}
  \hline \ughead{Signal} & \ugheadr{Direction} & \ugheadr{Width} & \ugheadr{Description} \\ \hline\hline \endfirsthead
  \hline \ughead{Signal} & \ugheadr{Direction} & \ugheadr{Width} & \ugheadr{Description} \\ \hline\hline \endhead
  \hline \endfoot
  \hline \caption{#1}\label{#2} \endlastfoot
}{\end{longtable}}

% {caption}{label}{first header}{second header}{first column width}
\newenvironment{twotable}[5]{%
  \Needspace*{7\baselineskip}%
  \setlength{\ugcola}{#5}%
  \setlength{\ugcolb}{\dimexpr\textwidth-\ugcola-4\tabcolsep-3\arrayrulewidth-1pt\relax}%
  \small
  \begin{longtable}{|>{\raggedright\arraybackslash}p{\ugcola}|>{\raggedright\arraybackslash}p{\ugcolb}|}
  \hline \ughead{#3} & \ugheadr{#4} \\ \hline\hline \endfirsthead
  \hline \ughead{#3} & \ugheadr{#4} \\ \hline\hline \endhead
  \hline \endfoot
  \hline \caption{#1}\label{#2} \endlastfoot
}{\end{longtable}}

% {caption}{label}{h1}{h2}{h3}{w1}{w2}
\newenvironment{threetable}[7]{%
  \Needspace*{7\baselineskip}%
  \setlength{\ugcola}{#6}\setlength{\ugcolb}{#7}%
  \setlength{\ugcolc}{\dimexpr\textwidth-\ugcola-\ugcolb-6\tabcolsep-4\arrayrulewidth-1pt\relax}%
  \small
  \begin{longtable}{|>{\raggedright\arraybackslash}p{\ugcola}|>{\raggedright\arraybackslash}p{\ugcolb}|>{\raggedright\arraybackslash}p{\ugcolc}|}
  \hline \ughead{#3} & \ugheadr{#4} & \ugheadr{#5} \\ \hline\hline \endfirsthead
  \hline \ughead{#3} & \ugheadr{#4} & \ugheadr{#5} \\ \hline\hline \endhead
  \hline \endfoot
  \hline \caption{#1}\label{#2} \endlastfoot
}{\end{longtable}}

% Names in text
\newcommand{\sig}[1]{\texttt{#1}}
\newcommand{\file}[1]{\texttt{#1}}

% Block diagrams: a chain of stages between operands and result
\tikzset{
  ugblock/.style={draw, fill=ug-block, rounded corners=1pt, minimum height=11mm, minimum width=19mm, align=center, font=\small},
  ugarrow/.style={-{Latex[length=2mm]}, thick},
  ugsym/.style={draw, fill=ug-block, minimum width=34mm, align=center, font=\small\ttfamily},
}

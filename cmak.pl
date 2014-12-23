#!/usr/bin/perl -w
#!/usr/local/bin/perl -w
#
# Auteur: Asher256
# Email:  contact@asher256.com
# 
# Dernière version: http://asher256.tuxfamily.org/cmak
#
# Licence :
#==========
# Ce code source est distribué sous licence GNU General Public
# Licence v2. Vous pouvez de le distribuer, l'utiliser, l'étudier
# ou l'améliorer. Pour plus d'informations lisez le fichier
# COPYING.txt ou COPYING-FR.txt distribués avec le code source.
#
# Description :
#==============
# CMak vous permet de créer un Makefile rapidement pour votre
# projet ou pour un besoin de compilation rapide (Si vous 
# trouvez sur internet par exemple un projet c/c++ qui ne
# contient aucun Makefile).
#
# La fonction "detect lib":
#==========================
# Si l'option --detect-lib est déclarée, le programme 
# détecte les bibliothèques de sous programmes requises
# par le code source en utilisant les directives
# "#include" déclarées dans les fichiers c/c++.
#
# Exemple: S'il y a un include "math.h", "-lm" sera 
#          automatiquement ajouté aux LDFLAGS.
#
# Le fichier cmak.cfg :
#======================
#
# Ce fichier est utilisé pour permettre de trouver la
# correspondance entre header<->cflags/ldflags (information
# utilisée par --detect-lib). Ce fichier peut être mis dans 
# plusieurs endroits:
#
#   * Sous Unix (par ex. Linux ou MacOSX):
#                ./cmak.cfg
#                $HOME/.cmak.cfg
#                /etc/cmak.cfg
#                /usr/share/cmak/cmak.cfg
#
#  * Sous Windows:
#		.\cmak.cfg
#		c:\cmak.cfg
#
# NB: La lecture des fichiers cmak.cfg se fait dans l'ordre
#     inverse de la liste ci-dessus. Cela veut dire que sous UNIX,
#     /usr/share/cmak/cmak.cfg est le premier à être lu (s'il existe).
#     Mais attention, c'est le dernier lu qui est le premier servi. Ainsi,
#     les correspondances entre Header<->CFLAGS/LDFLAGS de "./cmak.cfg" sont
#     prioritaires sur celles de "$HOME/.cmak.cfg" et celle de "/etc/cmak.cfg" 
#     sont prioritaires sur celles de "/usr/share/cmak/cmak.cfg".
#     
# NB: En vérité, le premier cmak.cfg lu c'est celui qui est 
#     déclaré avec l'option "--cfg". J'ai préféré le dire dans
#     le deuxième note pour plus de clareté dans l'explication :-)
#

use strict;     # Imposer la déclaration des variables
use warnings;   # Activer les warnings

use File::Basename; # dirname() basename()

# Const
my @valid_extention=("c","cpp","cxx","cc"); # Les extentions valides
my $cc="gcc:g++"; #compilateur c et c++

# Les variables modifiables par les arguments (et leurs valeurs par défaut)
my $makefile="Makefile";
my $detect_lib=0;
my $verbose=0;
my $interactive=0;
my $executable="";
my $ldflags="";
my $cflags="";
my $objdir="";
my $cmak_cfg="";
my @cpp_file_list=(); # liste de fichiers C/CPP passés dans les arguments

# Les variables modifiées pour une utilisation interne
my @include_path_list = (); # Liste des chemins pointant vers les includes
my $cpp_source=0; # =1 si un fichier de la liste est c++

# Correspondance entre Headers/CFLAGS/LDFLAGS (l'option --detect-lib)
my @cmak_header_list = ();
my @cmak_cflags_list = ();
my @cmak_ldflags_list = ();

# Defines internes du fichier cmak.cfg
my @define;
@define=(@define,"gcc"); # Toujours déclarée (car il n'y a que gcc qui est supporté par cmak pour le moment... TODO)
if($^O=~/linux/i) {
	@define=(@define, "linux", "unix");
}
elsif($^O=~/darwin/i) {
	@define=(@define, "darwin","unix");
}
elsif($^O=~/freebsd/i) {
	@define=(@define, "freebsd","unix");
}
elsif($^O=~/win/i) {
	@define=(@define, "win32", "windows");
}
else {
	print STDERR "ATTENTION: Systeme d'exploitation non detecte. Pour le moment, cette version de cmak\n";
	print STDERR "           connait Linux, Darwin, FreeBSD et Windows.\n";
	print STDERR "           Le programme va supposer que vous avez un systeme UNIX.\n\n";
	@define=(@define,"unix");
}

# On prend les arguments @ARGV
&get_arguments;

# Dois-on détecter automatiquement les bibliothèques de sous programmes ?
if($detect_lib) {
	# On charge le(s) fichier(s) cmak.cfg
	&load_cmak_cfg;

	# On va alimenter les CFLAGS et les LDFLAGS
	# en utilisant les fichiers *.h inclus dans tout le code source
	&auto_detect_lib;

	# Et enfin, on va donner un petit résultat affiché après la détection 
	# automatique des CFLAGS et LDFLAGS 
	$cflags  = &trim($cflags);
	$ldflags = &trim($ldflags);

	print "CFLAGS  = $cflags\n";
	print "LDFLAGS = $ldflags\n\n";
}
else {
	# On cherche dans tous les fichiers C/C++ ou se trouve la fonction main()
	&auto_detect_main();

	$cflags  = &trim($cflags);
	$ldflags = &trim($ldflags);
}

# Dans le cas ou l'utilisateur a demandé le mode interactif
# on va lui poser certaines questions...
&interactive_mode;

# On va enfin générer le Makefile
&create_makefile;

#
# Similaire à la commande print. Elle affiche le string lorsque
# le mode verbose est activé.
#
sub vprint {
	if($verbose) {
		foreach (@_) { print $_; }
	}
}

#
# Mode interactif
# On va demander certaines questions à l'utilisateur
# avant de créer le Makefile (si l'argument -i existe)
#
sub interactive_mode {
	if($interactive!=0) {
		$makefile = &cmak_prompt("Entrez le Makefile",$makefile);
		$executable = &cmak_prompt("Entrez le nom du fichier executable",$executable);
	}
}

#
# Un petit prompt utilisé par le mode interactif (-i).
#
# $1 = string question
# $2 = valeur par défaut (quand l'utilisateur n'entre rien)
#
sub cmak_prompt {
	my ($question,$default) = (@_);
	print $question. " ($default): ";

	# On va faire la lecture du clavier
	my $v = <STDIN>;
	chomp($v); $v=&trim($v);
	if($v eq "") {
		$v=$default;
	}

	# On retourne enfin le résultat
	return $v;
}

#
# Chercher le fichier C/C++ qui contient la fonction main(). 
# Si c'est le bon, le nom de l'exécutable portera le nom de 
# ce fichier (sans l'extention bien sûre).
#
sub auto_detect_main {
	# l'exécutable doit être vide
	if($executable ne "") {
		return;
	}

	&vprint("Recherche de la fonction \"main\"...\n");
	# On parcours la liste des fichiers C/C++
	foreach (@cpp_file_list) {
		my $v=$_;
		&vprint("Scan du fichier \"$v\"...\n");
		if(&detect_main($v)) {
			&vprint("Fonction trouvee dans le fichier \"$v\"...\n");
			last; #c'est trouvé!
		}
	}
}

#
# détecter si main existe dans un fichier C/C++.
# La fonction retourne 1 si la fonction main() a été trouvée.
#
# $1 = Fichier C/C++
#
sub detect_main {
	my ($filename)=(@_);
	my $line;

	# Si l'exécutable est pleine... Pas la peine de faire
	# notre recherche
	if($executable ne "") {
		return 0;
	}

	# On ouvre le fichier en lecture
	open(HANDLE,"$filename") || die("Erreur lors de l'ouverture du fichier $filename en lecture...\n");

	# On parcours ce même fichier
	while(($line = <HANDLE>)) {
		chomp($line);
		# On teste si la ligne actuelle contient main
		# true si le résultat est ok
		if(&test_main($filename,$line)) {
			# Pour on ajoute le basename du filename (sans l'extention)
			$executable=&basename(&delext($filename));
			close(HANDLE);
			return 1; #fin!
		}
	}
	close(HANDLE);
	return 0;
}

#
# Permet de tester si une chaîne de caractères contient 
# une fonction main().
# 
# Si c'est le cas, elle retournera 1 et fera le nécessaire
# pour rendre le nom de l'exécutable similaire au fichier 
# c/c++ contenant maint().
#
# $1 = Le nom du fichier fichier.cpp (sans le chemin)
# $2 = string (le contenu de la ligne lue depuis le fichier C/C++)
#
sub test_main
{
	my ($filename,$line_str) = (@_);
	# L'exécutable doit être vide
	if($line_str=~/main/) {
		return 1;
	}
	return 0;
}

#
# Détecter automatiquement toutes les correspondances entre
# Headers<->CFLAGS|LDFLAGS en parcourant tous les fichiers
# C/C++.
#
sub auto_detect_lib
{
	# On parcours la liste des fichiers C/C++
	foreach (@cpp_file_list) {
		my $v=$_;
		&detect_lib($v,0);
	}
}

#
# Fonction appelée par auto_detect_lib() pour trouver toutes
# les correspondances entre les *.h et CFLAGS/LDFLAGS.
# 
# Cette fonction peut parcourir récursivement les headers.
#
# Elle ne scanne jamais un header deux fois (pour gagner du
# temps).
#
# $1 = fichier.h
# $2 = 0 si premier fichier. 1 Si deuxième (recursive). 2, etc.
# $3 = ignore error. 1 pour ignore les erreur. 0 sinon.
#
my @visited_header; # Les headers qu'on as visité...
sub detect_lib
{
	my ($filename,$recursive,$ignore_error)=(@_);

	# Dans le cas ou l'option verbose a été définie
	if($verbose) {
		print "   "x$recursive;
		print "\"$filename\"\n";
	}

	# On ajoute ce lien dans visited
	foreach (@visited_header) {
		if($_ eq $filename) {
			# déja visité...
			&vprint("IGNORE: Le fichier $filename a déjà été scanné\n");
			return 1;
		}
	}
	push(@visited_header,$filename);

	# On teste si l'on a atteint la fin du scan recursif...
	# 16 c'est suffisant!
	if($recursive>=16) {
		return 0; # MAXIMUM...
	}

	# Chercher le fichier .h selon son nom
	$filename = &search_header($filename);
	
	# Déclaration du nom de fichier en forme de variable locale
	my $HANDLE;

	# Ouverture du fichier pour le scan
	if(!open($HANDLE,$filename)) {
		print STDERR "Erreur lors de l'ouverture du fichier $filename en lecture...\nAjoutez un chemin de recherche pour les fichiers include avec l'option -I ou --include-dir\n";
		if(!$ignore_error) {
			exit 1;
		}
		return 1;
	}
	my $line_str;
	while(($line_str=<$HANDLE>)) {
		chomp($line_str);

		# S'il y a un include
		if($line_str=~/\s*\#include.*[\"<].*[\">]/) {
			my $include = $line_str;

			# On ne laisse que le fichier .h
			$include=~s/^\s*\#include\s*[\"<]//;
			$include=~s/[\">].*$//;

			# et là on le teste avec tous les headers
			my $i=0;
			foreach (@cmak_header_list) {
				# Test
				if($include=~/^$_/i) {
					# CFLAGS : il a été trouvé dans la liste?
					if(defined($cmak_cflags_list[$i]) and $cmak_cflags_list[$i] ne "") {
						$cflags.=" ".$cmak_cflags_list[$i];
						&vprint("Le fichier $filename contient $include donc CFLAGS.=".$cmak_cflags_list[$i]."\n");
					}

					# LDFLAGS : il a été trouvé dans la liste?
					if(defined($cmak_ldflags_list[$i]) and $cmak_ldflags_list[$i] ne "") {
						$ldflags.=" ".$cmak_ldflags_list[$i];
						&vprint("Le fichier $filename contient $include donc CFLAGS.=".$cmak_ldflags_list[$i]."\n");
					}

					# On vide le tout pour ne pas inclure deux fois la même chose
					$cmak_cflags_list[$i]="";
					$cmak_ldflags_list[$i]="";

					$i=-1;
					last; #FIN du test de tous les headers
				}

				# Incrémentation de $i afin d'avoir l'index à jour
				$i++;
			}

			# et enfin, on va faire une detect lib si celle-ci n'est 
			# pas détectée ($i!=-1   ==   pas détectée)
			if($i!=-1) {
				my $ignore=0;
				# si <...> au lieu de "..." on ignore l'erreur
				# d'un include non trouvé
				if($line_str=~/\#include.*<.*>/) { $ignore=1; }
				# On scanne le prochain fichier!
				&detect_lib($include,$recursive+1,$ignore);
			}
		}
		
		# Si la ligne ne contient pas #include
		# on va faire un petit test:
		# Si le fichier c/c++ contient le mot main on va le choisir pour
		# qu'il soit le nom par défaut du projet
		elsif($recursive==0) { # rec=0 donc c le fichier père. (le fich c/c++)
			if(&test_main($filename,$line_str)) {
				# On ajoute le basename() du filename c/c++ (sans l'extention)
				$executable=&basename(&delext($filename));
			}
		}
	}
	close($HANDLE);
}

#
# Chercher un header dans les chemins standard.
#
# $1 = fichier h
#
sub search_header
{
	my ($filename) = (@_);

	# On cherche dans -I
	foreach (@include_path_list) {
		if(-f $_."/".$filename) {
			return $_."/".$filename;
		}
	}
	
	# On cherche dans include
	if(-f "/usr/include/$filename") {
		return "/usr/include/$filename";
	}

	# On cherche dans include linux specific
	if(&cmak_defined("linux")) {
		if(-f "/usr/include/linux/$filename") {
			return "/usr/include/linux/$filename";
		}
	}

	# Dans le répertoire local
	if(-f "/usr/local/include/$filename") {
		return "/usr/local/include/$filename";
	}

	# Dans le cas ou l'on a rien trouvé
	# on retourne une valeur inchangée
	return $filename;
}

#
# Chargement de tous les fichiers "cmak.cfg".
#
sub load_cmak_cfg
{
	my $loaded=0;

	# S'il y a un cfg personnalisé qu'on doit charger
	if($cmak_cfg ne "") {
		&load_cmak_cfg_ex($cmak_cfg);
		$loaded=1;
	}
	
	# Dans le répertoire actuel
	if(-f "./cmak.cfg") {
		&load_cmak_cfg_ex("./cmak.cfg");
		$loaded=1;
	}

	# Cas d'un système unix (Linux ou MacOS-X)
	if(&cmak_defined("unix")) {
		# $HOME/.cmak.cfg
		my $home = $ENV{'HOME'};
		if($home ne "") {
			if(-f "$home/.cmak.cfg") {
				&load_cmak_cfg_ex("$home/cmak.cfg");
				$loaded=1;
			}
		}

		# et enfin le général...
		if(-f "/etc/cmak.cfg") {
			&load_cmak_cfg_ex("/etc/cmak.cfg");
			$loaded=1;
		}

		# et enfin le général...
		if(-f "/usr/share/cmak/cmak.cfg") {
			&load_cmak_cfg_ex("/usr/share/cmak/cmak.cfg");
			$loaded=1;
		}
	}

	# Cas d'un système Windows
	elsif(&cmak_defined("win32")) {
		if(-f "c:\\cmak.cfg") {
			&load_cmak_cfg_ex("c:\\cmak.cfg");
			$loaded=1;
		}
	}

	# il n'a pas été trouvé... :-(
	if($loaded==0) {
		print STDERR "Le fichier de configuration cmak.cfg est introuvable...\n";
		exit 1;
	}
}

#
# Chargement d'un fichier cfg.
# 
# $1 = chemin + nom du fichier cmak.cfg
#
sub load_cmak_cfg_ex
{
	my ($cmak_filename)=(@_); # par défaut c'est vide

	# Si le cmak filename a été trouvé
	print "Chargement de la configuration du fichier $cmak_filename\n";

	# Variables
	my $line = 0; # numéro de ligne
	my @ifdef_list = (); # liste des ifdef (push, pop selon ifdef/endif)
	my $ignore_cmd=0; # s'il y a un ifndef alors on ignore toutes les cmds header

	# Ouverture du fichier
	open(HANDLE,"$cmak_filename") || die("Erreur lors de l'ouverture du fichier $cmak_filename\n");
	my $l; # La ligne lue
	my $line_str; # Copie de $l utilisée en bas dans la boucle
	while(($l=<HANDLE>)) {
		chomp($l);

		$line_str=$l; #sauvegarde de la ligne dans line_str

		# Quelques premières modifications
		$line++;
		$l=~s/\#.*$//;     # On enlève le commentaire le commentaire après une #
		$l=&trim($l);  # On va enlever les espaces de gauche et de droite

		# Traitement de la commande + arguments
		my $command = $l;
		my $arg = $l;
		$command=~s/^([^\s]*).*$/$1/;
		$command=&rtrim($command);
		$arg=~s/^[^\s]*//;
		$arg=&trim($arg);

		# cmd: vide (ON IGNORE!)
		if($command eq "") { next; }

		# cmd: ifdef 
		if($command eq "ifdef") {
			$ignore_cmd = (&cmak_defined($arg))?0:1;
			push(@ifdef_list,$arg);
		}

		# cmd: endif
		elsif($command eq "endif") {
			my $ifdef_count=@ifdef_list;
			
			# on n'accepte pas d'arguments dans endif
			if($arg=~/[^\s].*/) {
				&cmak_error($cmak_filename,$line,$line_str,"endif n'accepte aucun argument.");
			}

			# S'il y a erreur (ifdef non déclaré)
			if($ifdef_count<=0) {
				&cmak_error($cmak_filename,$line,$line_str,"endif est declaree sans ifdef.");
			}

			# On enlève le précédent élément de la liste
			pop(@ifdef_list);

			$ignore_cmd=0; # par défaut on ignore pas

			# Si il y a encore un define dans la liste on va la tester pour savoir si
			# on ignore ou pas
			if(@ifdef_list>0) {
				$ignore_cmd = (&cmak_defined($ifdef_list[@ifdef_list-1]))?1:0;
			}
		}

		# Si on doit ignore les commandes c'est ici
		elsif($ignore_cmd==1) {
			next;
		}

		# define
		elsif($command eq "define") {
			&cmak_define($arg);
		}

		# enfin
		# cmd: header
		elsif($command eq "header") {
			my @table = split(/:/,$arg);

			# nombre d'arguments
			if(@table>3 or @table<2) {
				&cmak_error($cmak_filename,$line,$line_str,"La commande \"header\" n'accepte que 2 ou 3 arguments.");
			}
			
			# Lecture des arguments
			my ($arg_header,$arg_ldflags,$arg_cflags) = (@table);
			$arg_header=&trim($arg_header);
			$arg_cflags=&trim($arg_cflags);
			$arg_ldflags=&trim($arg_ldflags);
			
			# Ajout dans la liste
			push(@cmak_header_list,$arg_header);
			push(@cmak_ldflags_list,$arg_ldflags);
			push(@cmak_cflags_list,$arg_cflags);
		}

		# Erreur + quitter
		else {
			&cmak_error($cmak_filename,$line,$line_str,"Commande non reconnue");
		}
	}
	close(HANDLE);
}
  
#
# Erreur dans le fichier cmd!
#
# $1 : fichier
# $2 : ligne
# $3 : contenu de la ligne
# $4 : explication (optionnel)
#
sub cmak_error
{
	my ($cmak_filename,$line,$line_str,$explication) = (@_);
	print STDERR "Erreur dans le fichier $cmak_filename\n";
	print STDERR "Ligne:       $line\n";
	print STDERR "Contenu:     ".&trim($line_str)."\n";
	if($explication ne "") {
		print STDERR "Explication: ".$explication."\n";
	}
	exit 1;
}

#
# Ajouter une define cmak à la liste.
#
# $1 = define(str)
#
sub cmak_define
{
	push(@define,$_[0]);
}

#
# Pour savoir si une macro cmak a été définie.
#
# $1 = "constante"
#
sub cmak_defined
{
	my ($const) = (@_);
	foreach (@define) {
		if($const eq $_) {
			return 1;
		}
	}
	return 0;
}

#
# Créer un Makefile en utilisant toutes les variables
# modifiées par les précédentes fonctions.
#
sub create_makefile
{
	# Dans le cas ou le fichier exécutable n'est pas spécifié
	# par l'utilisateur et n'est pas détecté:
	# "On va mettre main par défaut"
	if($executable eq "") {
		$executable = "main";
	}
	
	# On change de compilateur si c'est important
	if($cpp_source) {
		my @split=split(/:/,$cc);
		$cc=$split[1]; # Compilateur C++ (après les :)
	}
	else {
		my @split=split(/:/,$cc);
		$cc=$split[0]; # Compilateur C
	}
	
	# Création du makefile
	print "Creation du fichier \"$makefile\"...\n";

	# On ouvre le Makefile en écriture
	open(HANDLE,">$makefile") || die("Erreur lors de l'ouverture du fichier $makefile en ecriture...\n");

	# Début du fichier Makefile
	print HANDLE "#--------------------------------------------------------------\n";
	print HANDLE "# Makefile generated with cmak version.\n";

	# Insertion de l'heure et la date
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);	

	print HANDLE "# Date: $mday/$mon/".($year+1900)." $hour:$min:$sec\n";

	# Fin du premier commentaire dans le Makefile
	print HANDLE "#--------------------------------------------------------------\n\n";

	# Les variables importantes du Makefile
	print HANDLE "PREFIX  = /usr/local\n";
	print HANDLE "CFLAGS  = $cflags\n";
	print HANDLE "LDFLAGS = $ldflags\n\n";

	print HANDLE "CC = $cc\n";
	print HANDLE "RM = rm -f\n";
	print HANDLE "INSTALL_PROG = install -m 755 -s\n\n";
	
	print HANDLE "EXE = $executable\n";

	# EXE NAME
	my $exe_base=&basename($executable);
	if($exe_base ne $executable) {
		print HANDLE "EXE_BASE = ".$exe_base."\n\n";
	}
	else {
		print HANDLE "\n";
	}

	# On va mettre la liste des fichiers OBJ
	print HANDLE "OBJS =";
	foreach (@cpp_file_list) {
		print HANDLE " ";

		# Ajoute l'objdir
		if($objdir ne "") {
			print HANDLE $objdir."/";
		}

		# Ajoute le fichier o
		print HANDLE &delext($_).".o";
	}
	
	# ALL
	print HANDLE "\n\nALL : \$(EXE)\n\n";

	# Ajoute toutes les compilations
	foreach (@cpp_file_list) {
		#Création du nom du fichier obj
		my $obj=&delext($_).".o";

		# Ajoute le chemin du fichier obj (si c'est défini)
		if($objdir ne "") {
			$obj=$objdir."/".$obj;
		}
		
		#écriture dans le Makefile
		print HANDLE "$obj : $_\n";
		print HANDLE "\t\$(CC) -c $_ \$(CFLAGS) -o $obj\n\n";
	}

	# Ajoute maintenant la linkage
	print HANDLE "\$(EXE) : \$(OBJS)\n";
	print HANDLE "\t\$(CC) \$(OBJS) -o \$(EXE) \$(LDFLAGS)\n\n";

	# install: (système unix seulement)
	if(&cmak_defined("unix")) {
		print HANDLE "install : \$(EXE)\n";
		print HANDLE "\t\$(INSTALL_PROG) \$(EXE) \$(PREFIX)/bin\n\n";
	}

	# uninstall:
	print HANDLE "uninstall :\n";
	if($executable ne $exe_base) {
		print HANDLE "\t\$(RM) \$(PREFIX)/bin/\$(EXE_BASE)\n\n";
	}
	else {
		print HANDLE "\t\$(RM) \$(PREFIX)/bin/\$(EXE)\n\n";
	}

	# clean:
	print HANDLE "clean :\n";
	print HANDLE "\t\$(RM) \$(OBJS) \$(EXE)";

	# Fermeture
	close(HANDLE);
}

#
# Lecture de tous les arguments.
#
# Cette fonction quitte s'il y a une erreur.
#
sub get_arguments
{
	my $fin_option=0; # si -- alors aucun option ne sera lue
	my $i;
	
	# Si l'utilisateur ne définit aucune option on va lui afficher l'aide
	if(@ARGV==0) {
		&help;
	}
	
	# On parcours toutes les options
	for($i=0;$i<@ARGV;$i++) {
		$_=$ARGV[$i];
		# NB: for($i) au lieu de foreach() car on va utiliser ++$i pour avoir le prochaine arg

		# Pour en finir avec les options
		if($_ eq "--") {
			$fin_option=1;
			next;
		}
		
		# Si les options sont finies alors on ajoute les fichier C/CPP seulement
		if($fin_option) {
			&cpp_file($_);
			next;
		}
		
		#* Ici on test les options mono
		
		# --detect-lib (détection automatique de librairie)
		elsif($_ eq "--detect-lib" or $_ eq "-dl") {
			$detect_lib=1;
		}

		# --interactive
		elsif($_ eq "--interactive" or $_ eq "-i") {
			$interactive=1;
		}

		# --verbose
		elsif($_ eq "--verbose" or $_ eq "-v") {
			$verbose=1;
		}

		# Aide --help ou -h
		elsif($_ eq "--help" or $_ eq "-h") {
			&help;
		}

		#* On teste les autres options. ex: -e value

		# --obj-dir
		elsif($_ eq "-od" or $_ eq "--obj-dir") {
			$objdir=$ARGV[++$i];
		}

		# --cflags
		elsif($_ eq "-C" or $_ eq "--cflags") {
			$cflags.=" ".$ARGV[++$i];
		}

		# --ldflags
		elsif($_ eq "-LD" or $_ eq "--ldflags") {
			$ldflags.=" ".$ARGV[++$i];
		}

		# --lib-dir
		elsif($_ eq "-L" or $_ eq "--lib-dir") {
			$cflags.=" -L".$ARGV[++$i];
		}

		# --include-dir
		elsif($_ eq "-I" or $_ eq "--include-dir") {
			$cflags.=" -I".$ARGV[++$i];
			push(@include_path_list,$ARGV[$i]);
		}


		# choisir le chemin du fichier config
		elsif($_ eq "--cfg") {
			$cmak_cfg=$ARGV[++$i];
		}
		
		# --executable
		elsif($_ eq "-e" or $_ eq "--executable") {
			$executable=$ARGV[++$i];
		}

		# --makefile
		elsif($_ eq "-m" or $_ eq "--makefile") {
			$makefile=$ARGV[++$i];
		}

		# Si ce n'est pas une option alors ajouter le fichier .cpp
		else {
			&cpp_file($_);
			next;
		}

		# si c'est une option alors tester s'il y a eu un dépassement
		if($i>=@ARGV) {
			print STDERR "Erreur dans l'argument ".($i)." contenant \"".$ARGV[$i-1]."\"...\n";
			print STDERR "--help pour plus d'informations.\n";
			exit 1;
		}
	}

	# on doit absolument entrer un fichier c/c++
	if(@cpp_file_list == 0) {
		print STDERR "Vous devez au moins entrer un fichiers C/C++ dans les arguments.\n";
		print STDERR "--help pour plus d'informations\n";
		exit 1;
	}
}

#
# Enlève l'extention d'un nom de fichier.
# Le résultat est retourné.
#
# $1 = fichier avec extention
#
sub delext
{
	my ($filename) = (@_);
	if(defined($filename)) {
		$filename=~s/\.[^.]*$//;
	}
	return $filename;
}

#
# Ajoute un fichier C/C++ à la liste.
# Quitte s'il y a une erreur.
#
# $1 = fichier c/c++
#
sub cpp_file
{
	my ($filename) = (@_);
	my $ext;

	# On teste l'existence du fichier
	if(not -f $filename) {
		print "Le fichier \"$filename\" n'existe pas...\n";
		exit 1;
	}

	# On prend l'extention
	$ext = $filename;
	$ext=~s/^.*\.//;

	# On teste le fichier (si l'extention est bonne)
	my $invalid_extention=1;
	if($filename=~/\./) {
		foreach (@valid_extention){
			if($_ eq $ext) {
				$invalid_extention=0;
				# Test si c ou c++
				$cpp_source=($ext eq "c")?0:1;
				last;
			}
		}
	}
	
	# Si l'extention n'est pas bonne
	if($invalid_extention) {
		print STDERR "Le fichier \"$filename\" ne contient pas une extention c/c++ valide.\n";
		print STDERR "Les extentions acceptées: @valid_extention\n";
		exit 1;
	}
	
	# on ajoute le fichier à la liste
	push(@cpp_file_list,$filename);
}

#
# Une petite aide + exit
#
sub help
{
	# Petite aide pour l'utilisateur
	print "cmak, Generateur automatique de Makefile\n";
	print "Auteur: Asher256 <contact\@asher256.com>\n";
	print "\n";
	print "(les accents ont ete enleves pour eliminer les conflits dans l'encodage entre\n";
	print "UTF-8 et ISO-8859-1)\n";
	print "\n";
	print "Syntaxe: cmak [options] fichier1.cpp fichier2.c etc...\n";
	print "\n";
	print "Options:\n";
	print "    -h,  --help                     Aide sur les options\n";
	print "    -v,  --verbose                  Afficher plus d'informations que la normale\n";
	print "    -i,  --interactive              Mode interactif (demande des questions)\n\n";

	print "    -dl, --detect-lib               Detecte automatiquement les bibliotheques\n";
	print "                                    selon les headers dans le code source.\n";
	print "                                    Editez le fichier cmak.cfg pour\n";
	print "                                    personnaliser cette detection\n";
	print "\n";
	print "    --cfg <chemin/fichier.cfg>      Choisir manuellement le chemin de cmak.cfg\n";
	print "\n";
	print "    -m,  --makefile   <fichier>     Le fichier Makefile (par defaut 'Makefile')\n";
	print "\n";
	print "    -e,  --executable <fichier>     Le fichier executable genere apres la\n";
	print "                                    compilation\n";
	print "\n";
	print "    -od, --obj-dir <repertoire>     Le repertoire ou seront mis les fichiers .o\n";
	print "\n";
	print "    -L,  --lib-dir <repertoire>     Cette option peut etre definie plusieurs\n";
	print "                                    fois. Elle permet d'indiquer le chemin\n";
	print "                                    des bibliotheques .a\n";
	print "\n";
	print "    -I,  --include-dir <rep>        Cette option peut etre definie plusieurs\n";
	print "                                    fois. Elle permet d'indiquer le chemin des\n";
	print "                                    fichier .h\n";
	print "\n";
	print "    -C,  --cflags <flags>           Ajouter aux CFLAGS une option (peut etre\n";
	print "                                    definie plusieurs fois)\n\n";
	
	print "    -LD, --ldflags <flags>          Ajouter aux LDFLAGS une option (peut etre\n";
	print "                                    definie plusieurs fois)\n";
	print "\n";

	# Et enfin, on quitte ;-)
	exit 0;
}

#
# enlever les espaces à gauche et à droite d'un string
#
sub trim
{
	my ($string) = (@_);
	return &ltrim(&rtrim($string));
}

#
# Enlever les espaces à gauche d'un string
#
sub ltrim
{
	my ($string) = (@_);
	if(defined($string)) {
		$string =~ s/^\s+//;
	}
	return $string;
}

#
# Enlever les espaces à droite d'un string
#
sub rtrim
{
	my ($string) = (@_);
	if(defined($string)) {
		$string =~ s/\s+$//;
	}
	return $string;
}


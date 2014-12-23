cmak, C/C++ Makefile Generator

Auteur:  Asher256
Email:   contact@asher256.com
URL:     http://asher256.tuxfamily.org/cmak

Licence
======================================================================
cmak est distribué selon les termes de la GNU General Public Licence.

Qu'est-ce que cmak?
======================================================================
Il nous arrive des fois de trouver sur internet des codes source ne 
contenant aucun Makefile, juste un petit fichier spécifique à une
IDE (en majorité propriétaire).

CMAK est un générateur automatique de Makefile qui peut être utilisé par
exemple pour votre projet C/C++ ou encore pour un besoin de compilation
rapide. Il peut aussi être très utile pour toute personne qui débute 
dans la programmation C/C++ et qui a besoin de créer plusieurs 
Makefiles pour ses nombreux tests.

La détection de bibliothèques
======================================================================
Il nous arrive aussi que ce même code source requiert plusieurs dépendances
(par exemple SDL, Gtk+, Fltk, etc.). Cela fait perdre du beaucoup de temps 
de commencer à rechercher ces dépendances pour les ajouter au Makefile. Une 
des fonctions les plus intéressantes de CMAK est qu'il permet de détecter
ces  dépendances via le fichier de configuration cmak.cfg, en parcourant
récursivement tous les fichiers *.h inclus dans le code source. 

Premier exemple qui nous montre la détection de bibliothèques :
---------------------------------------------------------------
Imaginons un code source qui contient le fichier: calcul.cpp
	* Le fichier "calcul.cpp" contient:  #include "calcul.h"
	* Le fichier "calcul.h" contient: #include "calcul_general.h"
	* Le fichier "calcul_general.h" contient: "#include <math.h>"

Une fois que cmak aura traversé calcul.cpp->calcul.h->calcul_general.h
il ajoutera automatique -lm dans les LDFLAGS car "calcul_general.h"
contient <math.h> (-lm permet d'utiliser les fonction comme sin() ou cos()).

La correspondances entre <math.h> et -lm se trouve dans le fichier "cmak.cfg".
Lisez le contenu du fichier cmak.cfg pour savoir comment ajouter vos propres 
correspondances.

Deuxième exemple:
-----------------
Imaginez que vous avez un code source qui contient:
	* 10 fichiers C/C++ dans src/ et src_lib/
	* 5 fichiers .h dans include/
	* La code source qui requiert les bibliothèques SDL, Fltk (ce que
	  vous ne savez pas et que cmak va le deviner pour vous avec
          l'option --detect-lib).

Avec cmak, il suffit de lancer la commande :

$ cmak src/*.c* src_lib/*.c* --detect-lib -I include

Le programme va automatiquement détecter les bibliothèques requises par 
le code source (cad SDL et Fltk) pour ajouter leurs CFLAGS et 
leurs LDFLAGS respectifs dans le Makefile généré.
(exemple LDFLAGS: `sdl-config --libs` `fltk-config --ldflags`).

Explications de quelques options:

"--detect-lib" permet d'activer la détection automatique des bibliotèques.

"-I include" permet de spécifier le chemin des fichiers include.

Comment installer cmak sous Linux?
======================================================================
NB: Vous devez avoir le programme "make".

Entrez la commande dans votre terminal (en tant que root) :

$ make install

Un petit résumé sur l'utilisation de cmak?
======================================================================
Allez dans le répertoire ou sont situés les fichiers C/C++, puis 
lancer cmak avec tous les fichiers dans les arguments.

Par exemple:

$ cmak *.cpp

(un Makefile va être créé qui vous permettra de compiler tous les
fichiers .cpp).

Si vous souhaitez que cmak détecte automatiquement les bibliothèques
de sous programmes afin de compléter les CFLAGS et les LDFLAGS, ajoutez
l'option --detect-lib dans les arguments:

$ cmak --detect-lib *.cpp

Je vous invite à découvrir les autres options avec la commande:

$ cmak --help

Vous pouvez aussi consulter le fichier man qui contient beaucoup plus d'informations :

$ man cmak


# cmak, générateur de Makefile C/C++

**Auteur :** Asher256
**URL :** https://github.com/Asher256/cmak
**Contact :** https://github.com/Asher256/cmak/issues

# Licence

L'outil `cmak` est distribué selon les termes de la GNU General Public License.

# Qu'est-ce que cmak ?

Il arrive parfois de trouver sur Internet des codes sources ne contenant aucun Makefile, uniquement un fichier spécifique à un IDE.

L'outil `cmak` est un générateur automatique de Makefile qui peut être utilisé, par exemple, pour vos projets C/C++ ou pour des besoins de compilation rapide. Il peut aussi être très utile aux personnes débutant en programmation C/C++ et ayant besoin de créer plusieurs Makefiles pour leurs nombreux tests.

# La détection de bibliothèques

Il arrive également qu’un code source requière plusieurs dépendances (par exemple SDL, Gtk+, Fltk, etc.). Cela fait perdre du temps de rechercher ces dépendances pour les ajouter manuellement au Makefile.

L’une des fonctionnalités de `cmak` est sa capacité à détecter automatiquement ces dépendances via le fichier de configuration `cmak.cfg`, en parcourant récursivement tous les fichiers `*.h` inclus dans le code source.

## Premier exemple : détection de bibliothèques

Imaginons un code source contenant le fichier `calcul.cpp` :

- Le fichier `calcul.cpp` contient :
  ```cpp
  #include "calcul.h"
  ```

- Le fichier `calcul.h` contient :
  ```cpp
  #include "calcul_general.h"
  ```

- Le fichier `calcul_general.h` contient :
  ```cpp
  #include <math.h>
  ```

Une fois que cmak aura parcouru :

```text
calcul.cpp -> calcul.h -> calcul_general.h
```

Il ajoutera automatiquement `-lm` dans les `LDFLAGS`, car `calcul_general.h` contient `<math.h>` (`-lm` permet d’utiliser des fonctions comme `sin()` ou `cos()`).

La correspondance entre `<math.h>` et `-lm` se trouve dans le fichier `cmak.cfg`.

Consultez le contenu du fichier `cmak.cfg` pour savoir comment ajouter vos propres correspondances.

## Deuxième exemple

Imaginons que vous avez un code source contenant :

- 10 fichiers C/C++ dans `src/` et `src_lib/`
- 5 fichiers `.h` dans `include/`
- Un code source nécessitant les bibliothèques SDL et Fltk (ce que vous ignorez, mais que cmak détectera automatiquement grâce à l’option `--detect-lib`)

Avec cmak, il suffit de lancer la commande :

```bash
cmak src/*.c* src_lib/*.c* --detect-lib -I include
```

Le programme détectera automatiquement les bibliothèques requises par le code source (ici SDL et Fltk) afin d’ajouter leurs `CFLAGS` et `LDFLAGS` respectifs dans le Makefile généré.

Exemple de `LDFLAGS` :

```bash
`sdl-config --libs` `fltk-config --ldflags`
```

### Explication de quelques options

#### `--detect-lib`

Active la détection automatique des bibliothèques.

#### `-I include`

Permet de spécifier le chemin des fichiers d’en-tête (`include`).

# Comment installer cmak sous Linux ?

**NB :** Vous devez avoir le programme `make` installé.

Entrez la commande suivante dans votre terminal (en tant que `root`) :

```bash
make install
```

# Résumé de l’utilisation de cmak

Placez-vous dans le répertoire contenant les fichiers C/C++, puis lancez cmak en passant tous les fichiers en argument.

Par exemple :

```bash
cmak *.cpp
```

Un `Makefile` sera créé afin de compiler tous les fichiers `.cpp`.

Si vous souhaitez que cmak détecte automatiquement les bibliothèques utilisées afin de compléter les `CFLAGS` et `LDFLAGS`, ajoutez l’option `--detect-lib` :

```bash
cmak --detect-lib *.cpp
```

Pour découvrir les autres options disponibles :

```bash
cmak --help
```

Vous pouvez également consulter la page de manuel contenant davantage d’informations :

```bash
man cmak
```

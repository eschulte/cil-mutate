# -*- shell-script -*-
# Maintainer: Eric Schulte <schulte.eric@gmail.com>
#
# Use the following to install cil on
# Arch. https://aur.archlinux.org/packages/cil-git/
#
# Also, note that you might have to do something like the following to
# re-install ocamlfind with the "'staticlibs'" in the "options" array.
# 
# mkdir /tmp/ocaml-findlib/
# pushd /tmp/ocaml-findlib/
# URL="https://projects.archlinux.org/svntogit/community.git/plain/trunk/PKGBUILD?h=packages/ocaml-findlib"
# curl "$URL"|sed "s/'zipman'/'zipman' 'staticlibs'/" >PKGBUILD
# makepkg
# pacman -R ocaml-findlib
# pacman -U ocaml-findlib-*
# popd
# 
# 2. manually add "'staticlibs'" to the "options" array in the
#    ocaml-findlib PKGBUILD file
#    
# 
# 3. build and install the resulting updated ocaml-findlib package 
pkgname=cil-mutate-git
pkgver=v.1.0.r5.g6049e43
pkgrel=1
pkgdesc="Manipulate C Intermediate Language ASTs with CIL"
arch=('i686' 'x86_64')
url="https://github.com/eschulte/cil-mutate"
license=('GPL')
makedepends=('git' 'cil')
provides=('cil-mutate')
source=("$pkgname::git://github.com/eschulte/cil-mutate.git")
md5sums=('SKIP')

pkgver() {
  cd "$srcdir/$pkgname"
  git describe --long --tags |sed -r 's/([^-]*-g)/r\1/;s/-/./g'
}

build() {
  cd "$srcdir/$pkgname"
  make
}

package() {
  cd "$srcdir/$pkgname"
  make DESTDIR=$pkgdir install
}

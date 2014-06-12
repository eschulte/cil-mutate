# -*- shell-script -*-
# Maintainer: Eric Schulte <schulte.eric@gmail.com>
pkgname=cil-mutate-git
pkgver=283110a
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
  git describe --always|sed 's/-/./g;s/ //g'
}

build() {
  cd "$srcdir/$pkgname"
  make
}

package() {
  cd "$srcdir/$pkgname"
  make DESTDIR=$pkgdir install
}

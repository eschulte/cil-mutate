# -*- shell-script -*-
# Maintainer: Eric Schulte <schulte.eric@gmail.com>
pkgname=cil-mutate-git
pkgver=20121030
pkgrel=1
pkgdesc="Manipulate C Intermediate Language ASTs with CIL"
arch=('i686' 'x86_64')
url="https://github.com/eschulte/cil-mutate"
license=('GPL')
makedepends=('git' 'cil')
provides=('cil-mutate')

_gitroot="git://github.com/eschulte/cil-mutate.git"
_gitname="cil-mutate"

build() {
  cd "$srcdir"
  msg "Connecting to GIT server...."

  ## Git checkout
  if [ -d $_gitname ] ; then
    pushd $_gitname && git pull origin && popd
  else
    git clone $_gitroot $_gitname
  fi
  msg "Checkout completed"

  ## Build
  msg "Building..."
  cd $_gitname
  make
}

package() {
  cd "$srcdir/"${_gitname}
  make DESTDIR=$pkgdir install
}

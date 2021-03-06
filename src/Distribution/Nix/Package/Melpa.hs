{-

emacs2nix - Generate Nix expressions for Emacs packages
Copyright (C) 2016 Thomas Tuegel

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

-}

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Distribution.Nix.Package.Melpa ( Package(..), Recipe(..), expression ) where

import Data.Fix
import Data.Text ( Text )
import qualified Data.Text as T
import Nix.Types

import Distribution.Nix.Builtin
import Distribution.Nix.Fetch ( Fetch, fetchExpr, importFetcher )
import Distribution.Nix.Name

data Package
  = Package
    { pname :: !Name
    , version :: !Text
    , fetch :: !Fetch
    , deps :: ![Name]
    , recipe :: !Recipe
    }

data Recipe
  = Recipe { ename :: !Text
           , commit :: !Text
           , sha256 :: !Text
           }

expression :: Package -> NExpr
expression (Package {..}) = (mkSym "callPackage") `mkApp` drv `mkApp` emptySet where
  drv = mkFunction args body
  emptySet = mkNonRecSet []
  requires = map fromName deps
  args = (mkFixedParamSet . map optionalBuiltins)
         ("lib" : "melpaBuild" : "fetchurl" : importFetcher fetch : requires)
  body = (mkApp (mkSym "melpaBuild") . mkNonRecSet)
         [ "pname" `bindTo` mkStr DoubleQuoted (fromName pname)
         , "version" `bindTo` mkStr DoubleQuoted version
         , "src" `bindTo` fetchExpr fetch
         , "recipeFile" `bindTo` fetchRecipe
         , "packageRequires" `bindTo` mkList (map mkSym requires)
         , "meta" `bindTo` meta
         ]
    where
      meta = mkNonRecSet
             [ "homepage" `bindTo` mkStr DoubleQuoted homepage
             , "license" `bindTo` license
             ]
        where
          homepage = T.append "http://melpa.org/#/" (ename recipe)
          license = Fix (NSelect (mkSym "lib") [StaticKey "licenses", StaticKey "free"] Nothing)
      fetchRecipe = (mkApp (mkSym "fetchurl") . mkNonRecSet)
                    [ "url" `bindTo` mkStr DoubleQuoted
                      (T.concat
                       [ "https://raw.githubusercontent.com/milkypostman/melpa/"
                       , commit recipe
                       , "/recipes/"
                       , ename recipe
                       ])
                    , "sha256" `bindTo` mkStr DoubleQuoted (sha256 recipe)
                    , "name" `bindTo` mkStr DoubleQuoted (fromName (fromText (ename recipe)))
                    ]

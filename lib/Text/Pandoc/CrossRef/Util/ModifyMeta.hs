{-
pandoc-crossref is a pandoc filter for numbering figures,
equations, tables and cross-references to them.
Copyright (C) 2015  Nikolay Yakimov <root@livid.pp.ru>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
-}

{-# LANGUAGE RecordWildCards #-}

module Text.Pandoc.CrossRef.Util.ModifyMeta
    (
    modifyMeta
    ) where

import Data.List (intercalate)
import Text.Pandoc
import Text.Pandoc.Shared (blocksToInlines)
import Text.Pandoc.Builder hiding ((<>))
import Text.Pandoc.CrossRef.Util.Options
import Text.Pandoc.CrossRef.References.Types
import Text.Pandoc.CrossRef.Util.Settings.Types
import Text.Pandoc.CrossRef.Util.Util
import qualified Data.Text as T

modifyMeta :: CrossRef Meta
modifyMeta = do
  opts@Options{..} <- asks creOptions
  settings <- asks creSettings
  let
    headerInc :: Maybe MetaValue -> MetaValue
    headerInc Nothing = incList
    headerInc (Just (MetaList x)) = MetaList $ x ++ [incList]
    headerInc (Just x) = MetaList [x, incList]
    incList = MetaBlocks $ return $ RawBlock (Format "latex") $ unlines $ execWriter $ do
        tell [ "\\makeatletter" ]
        tell subfig
        tell floatnames
        tell listnames
        unless listings $
          tell codelisting
        tell lolcommand
        when cref $ do
          tell cleveref
          unless listings $
            tell cleverefCodelisting
        tell [ "\\makeatother" ]
    subfig = [
        usepackage [] "subfig"
      , usepackage [] "caption"
      , "\\captionsetup[subfloat]{margin=0.5em}"
      ]
    floatnames = [
        "\\AtBeginDocument{%"
      , "\\renewcommand*\\figurename{"++getFloatCaption "fig"++"}"
      , "\\renewcommand*\\tablename{"++getFloatCaption "tbl"++"}"
      , "}"
      ]
    listnames = [
        "\\AtBeginDocument{%"
      , "\\renewcommand*\\listfigurename{"++getListOfTitle "fig"++"}"
      , "\\renewcommand*\\listtablename{"++getListOfTitle "tbl"++"}"
      , "}"
      ]
    codelisting = [
        usepackage [] "float"
      , "\\floatstyle{ruled}"
      , "\\@ifundefined{c@chapter}{\\newfloat{codelisting}{h}{lop}}{\\newfloat{codelisting}{h}{lop}[chapter]}"
      , "\\floatname{codelisting}{"++getFloatCaption "lst"++"}"
      ]
    lolcommand
      | listings = [
          "\\newcommand*\\listoflistings\\lstlistoflistings"
        , "\\AtBeginDocument{%"
        , "\\renewcommand*{\\lstlistlistingname}{"++getListOfTitle "lst"++"}"
        , "}"
        ]
      | otherwise = ["\\newcommand*\\listoflistings{\\listof{codelisting}{"++getListOfTitle "lst"++"}}"]
    cleveref = [ usepackage cleverefOpts "cleveref" ]
      -- <> crefname "figure" (pfxRef "fig")
      -- <> crefname "table" (pfxRef "tbl")
      -- <> crefname "equation" (pfxRef "eq")
      -- <> crefname "listing" (pfxRef "lst")
      -- <> crefname "section" (pfxRef "sec")
    -- pfxRef labelPrefix = prefixRef . flip getPfx labelPrefix
    cleverefCodelisting = [
        "\\crefname{codelisting}{\\cref@listing@name}{\\cref@listing@name@plural}"
      , "\\Crefname{codelisting}{\\Cref@listing@name}{\\Cref@listing@name@plural}"
      ]
    cleverefOpts | nameInLink = [ "nameinlink" ]
                 | otherwise = []
    -- crefname n f = [
    --     "\\crefname{" ++ n ++ "}" ++ prefix f False
    --   , "\\Crefname{" ++ n ++ "}" ++ prefix f True
    --   ]
    usepackage [] p = "\\@ifpackageloaded{"++p++"}{}{\\usepackage{"++p++"}}"
    usepackage xs p = "\\@ifpackageloaded{"++p++"}{}{\\usepackage"++o++"{"++p++"}}"
      where o = "[" ++ intercalate "," xs ++ "]"
    toLatex = either (error . show) T.unpack . runPure . writeLaTeX def . Pandoc nullMeta . return . Plain
    -- TODO: Log
    getListOfTitle = either (const mempty) (toLatex . blocksToInlines . toList) . getTitleForListOf opts
    getFloatCaption = const mempty
    -- prefix f uc = "{" ++ toLatex (toList $ f opts uc 0) ++ "}" ++
    --               "{" ++ toLatex (toList $ f opts uc 1) ++ "}"

  return $ if isLatexFormat outFormat
  then setMeta "header-includes"
      (headerInc $ lookupSettings "header-includes" settings)
      $ unSettings settings
  else unSettings settings

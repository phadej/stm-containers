module MutableContainers.WordArray.Immutable where

import MutableContainers.Prelude hiding (lookup, toList)
import Data.Primitive.Array
import Data.Primitive.MutVar
import Control.Monad.Primitive
import qualified MutableContainers.WordArray.Bitmap as Bitmap


-- |
-- An immutable word array.
data WordArray e =
  WordArray {-# UNPACK #-} !Bitmap {-# UNPACK #-} !(Array e)

-- | 
-- A bitmap of set elements.
type Bitmap = Bitmap.Bitmap

-- |
-- An index of an element.
type Index = Int

-- |
-- An array with a single element at the specified index.
singleton :: Index -> e -> WordArray e
singleton i e = 
  let b = Bitmap.set i 0
      a = runST $ newArray 1 e >>= unsafeFreezeArray
      in WordArray b a

-- |
-- Set an element value at the index.
set :: Index -> e -> WordArray e -> WordArray e
set i e (WordArray b a) = 
  let 
    sparseIndex = Bitmap.sparseIndex i b
    size = Bitmap.size b
    in if Bitmap.isSet i b
      then 
        let a' = runST $ do
              ma' <- newArray size undefined
              forM_ [0 .. (size - 1)] $ \i -> indexArrayM a i >>= writeArray ma' i
              writeArray ma' sparseIndex e
              unsafeFreezeArray ma'
            in WordArray b a'
      else
        let a' = runST $ do
              ma' <- newArray (size + 1) undefined
              forM_ [0 .. (sparseIndex - 1)] $ \i -> indexArrayM a i >>= writeArray ma' i
              writeArray ma' sparseIndex e
              forM_ [sparseIndex .. (size - 1)] $ \i -> indexArrayM a i >>= writeArray ma' (i + 1)
              unsafeFreezeArray ma'
            b' = Bitmap.set i b
            in WordArray b' a'

-- |
-- Remove an element.
unset :: Index -> WordArray e -> WordArray e
unset i (WordArray b a) =
  if Bitmap.isSet i b
    then
      let 
        b' = Bitmap.invert i b
        a' = runST $ do
          ma' <- newArray (pred size) undefined
          forM_ [0 .. pred sparseIndex] $ \i -> indexArrayM a i >>= writeArray ma' i
          forM_ [succ sparseIndex .. pred size] $ \i -> indexArrayM a i >>= writeArray ma' (pred i)
          unsafeFreezeArray ma'
        sparseIndex = Bitmap.sparseIndex i b
        size = Bitmap.size b
        in WordArray b' a'
    else WordArray b a

-- |
-- Lookup an item at the index.
lookup :: Index -> WordArray e -> Maybe e
lookup i (WordArray b a) =
  if Bitmap.isSet i b
    then Just (indexArray a (Bitmap.sparseIndex i b))
    else Nothing

bitmap :: WordArray e -> Bitmap
bitmap (WordArray b _) = b


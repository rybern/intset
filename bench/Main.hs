-- |
--   Copyright   :  (c) Sam T. 2013
--   License     :  BSD3
--   Maintainer  :  pxqr.sta@gmail.com
--   Stability   :  experimental
--   Portability :  portable
--
--   Each function should be benchmarked at least in the following modes:
--
--     * sparse — to see worst case performance. Taking into account
--     both implementations I think [0,64..N] is pretty sparse.
--
--     * dense — to see expected performance. Again [0,2..N] is pretty
--     dense but not interval yet.
--
--     * interval — to see best case performance. Set should be one
--     single interval like [0..N].
--
--   This should help us unify benchmarks and make it more infomative.
--
{-# LANGUAGE BangPatterns #-}
module Main (main) where

import Criterion.Main

import Data.Bits
import           Data.ByteString (ByteString)
import qualified Data.ByteString as B
import Data.IntSet as S
import Data.IntSet.Buddy as SB
import Data.IntSet.Buddy.ByteString as SB
import Data.List as L
import Data.Word




fromByteString :: ByteString -> S.IntSet
fromByteString = S.fromDistinctAscList . indices 0 . B.unpack
  where
    indices _ []       = []
    indices n (w : ws) = wordIxs n w ++ indices (n + 8) ws

    wordIxs n w = L.map ((n +) . fst) $ L.filter snd $ zip [0..] (bits w)

    bits i = L.map (testBit i) [0..bitSize (0 :: Word8) - 1]

main :: IO ()
main = defaultMain $
  [ bench "fromList/O-2500"  $ nf S.fromList [0..2500]
  , bench "fromList/O-5000"  $ nf S.fromList [0..5000]
  , bench "fromList/O-10000" $ nf S.fromList [0..10000]
  , bench "fromList/O-20000" $ nf S.fromList [0..20000]
  , bench "fromList/O-20000" $ nf S.fromList (L.map (* 10) [0..20000])
  , bench "fromList/S-2500"  $ nf SB.fromList [0..2500]
  , bench "fromList/S-5000"  $ nf SB.fromList [0..5000]
  , bench "fromList/S-10000" $ nf SB.fromList [0..10000]
  , bench "fromList/S-20000" $ nf SB.fromList [0..20000]
  , bench "fromList/S-20000-sparse" $ nf SB.fromList (L.map (* 10) [0..20000])


  , let !s = S.fromList [1..50000] in
    bench "toList/50000" $ nf S.toList s

  , let !s = SB.fromList [1..50000] in
    bench "toList/50000" $ nf SB.toList s

  , let !bs = B.replicate 10000 255 in
    bench "fromByteString/10000-O" $ whnf Main.fromByteString bs

  , let !bs = B.replicate 1048576 255 in
    bench "fromByteString/8M-S-dense" $ whnf SB.fromByteString bs

--  , let !bs = B.replicate 1048576 85 in
--    bench "fromByteString/8M-S-sparse" $ whnf SB.fromByteString bs

  , let !bs = B.replicate 1048576 0 in
    bench "fromByteString/8M-S-empty" $ whnf SB.fromByteString bs

  , let !s = S.fromList [0..1000000] in
    bench "member/1000000" $ nf (L.all (`S.member` s)) [50000..100000]

  , let !s = SB.fromList [0..1000000] in
    bench "member/1000000" $ nf (L.all (`SB.member` s)) [50000..100000]

  , let !s = S.fromDistinctAscList [0,64..1000000 * 64 ] in
    bench "split/O-1M-10K-sparse" $
      whnf (flip (L.foldr ((snd .) . S.split)) [100,200..1000000]) s

  , let !s = SB.fromList [0,64..1000000 * 64 ] in
    bench "split/S-1M-10K-sparse" $
      whnf (flip (L.foldr ((snd .) . SB.split)) [100,200..1000000]) s

  , let !s = S.fromDistinctAscList [0..1000000] in
    bench "split/O-1M-10K-buddy" $
      whnf (flip (L.foldr ((snd .) . S.split)) [100,200..1000000]) s

  , let !s = SB.fromList [0..1000000] in
    bench "split/S-1M-10K-buddy" $
      whnf (flip (L.foldr ((snd .) . SB.split)) [100,200..1000000]) s

--  , bench "distinct/100000/O" $ nf S.fromDistinctAscList  [1..100000]
--  , bench "distinct/20000/S"  $ nf SB.fromDistinctAscList [1..20000]
  ] ++ concat
  [ mergeTempl S.union        SB.union        "union"
  , mergeTempl S.intersection SB.intersection "intersection"
  , mergeTempl S.difference   SB.difference   "difference"
  ]


mergeTempl :: (S.IntSet  -> S.IntSet  -> S.IntSet)
           -> (SB.IntSet -> SB.IntSet -> SB.IntSet)
           -> String -> [Benchmark]
mergeTempl sop bop n =
  [ let (!a, !b) = (S.fromList [0,64..10000 * 64], S.fromList [1,65..10000 * 64]) in
    bench (n ++"/O-10000-sparse-disjoint")  $ whnf (uncurry sop) (a, b)

  , let (!a, !b) = (S.fromList [0,64..10000 * 64], S.fromList [0,64..10000 * 64]) in
    bench (n ++"/O-10000-sparse-overlap")  $ whnf (uncurry sop) (a, b)

  , let (!a, !b) = (SB.fromList [0,64..10000 * 64], SB.fromList [1,65..10000 * 64]) in
    bench (n ++ "/S-10000-sparse-disjoint") $ whnf (uncurry bop) (a, b)

  , let (!a, !b) = (SB.fromList [0,64..10000 * 64], SB.fromList [0,64..10000 * 64]) in
    bench (n ++ "/S-10000-sparse-overlap") $ whnf (uncurry bop) (a, b)

  , let (!a, !b) = (S.fromList [0,2..500000 * 2], S.fromList [1,3..500000 * 2]) in
    bench (n ++ "/O-500000-dense-disjoint")  $ whnf (uncurry sop) (a, b)

  , let (!a, !b) = (S.fromList [0,2..500000 * 2], S.fromList [0,2..500000 * 2]) in
    bench (n ++ "/O-500000-dense-overlap")  $ whnf (uncurry sop) (a, b)

  , let (!a, !b) = (SB.fromList [0,2..500000 * 2], SB.fromList [1,3..500000 * 2]) in
    bench (n ++ "/S-500000-dense-disjoint") $ whnf (uncurry bop) (a, b)

  , let (!a, !b) = (SB.fromList [0,2..500000 * 2], SB.fromList [0,2..500000 * 2]) in
    bench (n ++ "/S-500000-dense-overlap") $ whnf (uncurry bop) (a, b)

  , let (!a, !b) = (S.fromList [0..500000], S.fromList [0..500000]) in
    bench (n ++ "/O-500000-buddy")  $ whnf (uncurry sop) (a, b)

  , let (!a, !b) = (SB.fromList [0..500000], SB.fromList [0..500000]) in
    bench (n ++ "/S-500000-buddy") $ whnf (uncurry bop) (a, b)
  ]
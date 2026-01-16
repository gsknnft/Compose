// TensorEquivalence.test.ts
// Off-chain property tests against TensorFlow.js.
// On-chain behavior is covered in packages/adapters/evm/test.

import * as tf from "@tensorflow/tfjs";
import fc from "fast-check";
import { describe, it, expect } from "vitest";

function addLocal(a: number[][], b: number[][]): number[][] {
  return a.map((row, i) => row.map((v, j) => v + b[i][j]));
}

function scaleLocal(a: number[][], s: number): number[][] {
  return a.map((row) => row.map((v) => v * s));
}

describe("TensorEquivalence: TensorFlow.js parity", () => {
  it("add(a, b) == tf.add(a, b)", () => {
    const A = [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9],
    ];
    const B = [
      [9, 8, 7],
      [6, 5, 4],
      [3, 2, 1],
    ];
    const local = addLocal(A, B);
    const tfC = tf.add(tf.tensor2d(A), tf.tensor2d(B)).arraySync();
    expect(local).toEqual(tfC);
  });

  it("scale(add(a, b), s) == tf.mul(tf.add(a, b), s)", () => {
    const A = [
      [1, 2],
      [3, 4],
    ];
    const B = [
      [4, 3],
      [2, 1],
    ];
    const s = 3;
    const local = scaleLocal(addLocal(A, B), s);
    const tfD = tf.mul(tf.add(tf.tensor2d(A), tf.tensor2d(B)), s).arraySync();
    expect(local).toEqual(tfD);
  });

  it("add(a, b) == add(b, a) [commutativity]", () => {
    const matrixArb: fc.Arbitrary<number[][]> = fc.array(
      fc.array(fc.integer(), { minLength: 1, maxLength: 5 }),
      { minLength: 1, maxLength: 5 }
    );
    fc.assert(
      fc.property(matrixArb, matrixArb, (A: number[][], B: number[][]) => {
        if (
          A.length !== B.length ||
          A.some((row: number[], i: number) => row.length !== B[i].length)
        ) {
          return true;
        }
        const ab = addLocal(A, B);
        const ba = addLocal(B, A);
        expect(ab).toEqual(ba);
      })
    );
  });

  it("scale(add(a, b), s) == add(scale(a, s), scale(b, s)) [distributivity]", () => {
    const matrixArb: fc.Arbitrary<number[][]> = fc.array(
      fc.array(fc.integer(), { minLength: 1, maxLength: 5 }),
      { minLength: 1, maxLength: 5 }
    );
    fc.assert(
      fc.property(
        matrixArb,
        matrixArb,
        fc.integer({ min: -10, max: 10 }),
        (A: number[][], B: number[][], s: number) => {
          if (
            A.length !== B.length ||
            A.some((row: number[], i: number) => row.length !== B[i].length)
          ) {
            return true;
          }
          const left = scaleLocal(addLocal(A, B), s);
          const right = addLocal(scaleLocal(A, s), scaleLocal(B, s));
          expect(left).toEqual(right);
        }
      )
    );
  });

  it("scale(a, 1) == a [idempotence]", () => {
    const matrixArb: fc.Arbitrary<number[][]> = fc.array(
      fc.array(fc.integer(), { minLength: 1, maxLength: 5 }),
      { minLength: 1, maxLength: 5 }
    );
    fc.assert(
      fc.property(matrixArb, (A: number[][]) => {
        const scaled = scaleLocal(A, 1);
        expect(scaled).toEqual(A);
      })
    );
  });
});

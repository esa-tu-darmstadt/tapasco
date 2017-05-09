package de.tu_darmstadt.cs.esa.tapasco

object Implicits {
  // scalastyle:off public.methods.have.type
  // scalastyle:off line.size.limit
  implicit class TupOps2[A, B](val x: (A, B)) extends AnyVal {
    def :+[C](y: C) = (x._1, x._2, y)
    def +:[C](y: C) = (y, x._1, x._2)
  }
  implicit class TupOps3[A, B, C](val x: (A, B, C)) extends AnyVal {
    def :+[D](y: D) = (x._1, x._2, x._3, y)
    def +:[D](y: D) = (y, x._1, x._2, x._3)
  }
  implicit class TupOps4[A, B, C, D](val x: (A, B, C, D)) extends AnyVal {
    def :+[E](y: E) = (x._1, x._2, x._3, x._4, y)
    def +:[E](y: E) = (y, x._1, x._2, x._3, x._4)
  }
  implicit class TupOps5[A, B, C, D, E](val x: (A, B, C, D, E)) extends AnyVal {
    def :+[F](y: F) = (x._1, x._2, x._3, x._4, x._5, y)
    def +:[F](y: F) = (y, x._1, x._2, x._3, x._4, x._5)
  }
  implicit class TupOps6[A, B, C, D, E, F](val x: (A, B, C, D, E, F)) extends AnyVal {
    def :+[G](y: G) = (x._1, x._2, x._3, x._4, x._5, x._6, y)
    def +:[G](y: G) = (y, x._1, x._2, x._3, x._4, x._5, x._6)
  }
  implicit class TupOps7[A, B, C, D, E, F, G](val x: (A, B, C, D, E, F, G)) extends AnyVal {
    def :+[H](y: H) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, y)
    def +:[H](y: H) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7)
  }
  implicit class TupOps8[A, B, C, D, E, F, G, H](val x: (A, B, C, D, E, F, G, H)) extends AnyVal {
    def :+[I](y: I) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, y)
    def +:[I](y: I) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8)
  }
  implicit class TupOps9[A, B, C, D, E, F, G, H, I](val x: (A, B, C, D, E, F, G, H, I)) extends AnyVal {
    def :+[J](y: J) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, y)
    def +:[J](y: J) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9)
  }
  implicit class TupOps10[A, B, C, D, E, F, G, H, I, J](val x: (A, B, C, D, E, F, G, H, I, J)) extends AnyVal {
    def :+[K](y: K) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, y)
    def +:[K](y: K) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10)
  }
  implicit class TupOps11[A, B, C, D, E, F, G, H, I, J, K](val x: (A, B, C, D, E, F, G, H, I, J, K)) extends AnyVal {
    def :+[L](y: L) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, y)
    def +:[L](y: L) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11)
  }
  implicit class TupOps12[A, B, C, D, E, F, G, H, I, J, K, L](val x: (A, B, C, D, E, F, G, H, I, J, K, L)) extends AnyVal {
    def :+[M](y: M) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, y)
    def +:[M](y: M) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12)
  }
  implicit class TupOps13[A, B, C, D, E, F, G, H, I, J, K, L, M](val x: (A, B, C, D, E, F, G, H, I, J, K, L, M)) extends AnyVal {
    def :+[N](y: N) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, y)
    def +:[N](y: N) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13)
  }
  implicit class TupOps14[A, B, C, D, E, F, G, H, I, J, K, L, M, N](val x: (A, B, C, D, E, F, G, H, I, J, K, L, M, N)) extends AnyVal {
    def :+[O](y: O) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, y)
    def +:[O](y: O) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14)
  }
  implicit class TupOps15[A, B, C, D, E, F, G, H, I, J, K, L, M, N, O](val x: (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O)) extends AnyVal {
    def :+[P](y: P) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15, y)
    def +:[P](y: P) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15)
  }
  implicit class TupOps16[A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P](val x: (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P)) extends AnyVal {
    def :+[Q](y: Q) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15, x._16, y)
    def +:[Q](y: Q) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15, x._16)
  }
  implicit class TupOps17[A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q](val x: (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q)) extends AnyVal {
    def :+[R](y: R) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15, x._16, x._17, y)
    def +:[R](y: R) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15, x._16, x._17)
  }
  implicit class TupOps18[A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R](val x: (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R)) extends AnyVal {
    def :+[S](y: S) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15, x._16, x._17, x._18, y)
    def +:[S](y: S) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15, x._16, x._17, x._18)
  }
  implicit class TupOps19[A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S](val x: (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S)) extends AnyVal {
    def :+[T](y: T) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15, x._16, x._17, x._18, x._19, y)
    def +:[T](y: T) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15, x._16, x._17, x._18, x._19)
  }
  implicit class TupOps20[A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T](val x: (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T)) extends AnyVal {
    def :+[U](y: U) = (x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15, x._16, x._17, x._18, x._19, x._20, y)
    def +:[U](y: U) = (y, x._1, x._2, x._3, x._4, x._5, x._6, x._7, x._8, x._9, x._10, x._11, x._12, x._13, x._14, x._15, x._16, x._17, x._18, x._19, x._20)
  }
  // scalastyle:on line.size.limit
  // scalastyle:on public.methods.have.type
}

/**
 *  @file	CumulativeAverage.hpp
 *  @brief	A class wrapping a lock-free cumulative (running) average.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef CUMULATIVE_AVERAGE_HPP__
#define CUMULATIVE_AVERAGE_HPP__

#include <atomic>
#include <limits>

/**
 * CumulativeAverage provides a stateful running average of a value.
 **/
template <typename T> class CumulativeAverage {
public:
  CumulativeAverage(T const init) : _data({.value = init, .delta = init,
      .min = std::numeric_limits<T>::max(), .max = std::numeric_limits<T>::min(),
      .count = 0}) {}
  virtual ~CumulativeAverage() {}

  T update(T const t) {
    struct data_t o;
    struct data_t n;
    do {
      o = _data.load();
      n = o;
      n.count = o.count + 1;
      n.value = (o.value * o.count + t) / n.count;
      n.delta = n.value - o.value;
      n.min = n.min < t ? n.min : t;
      n.max = n.max > t ? n.max : t;
    } while (! _data.compare_exchange_strong(o, n));
    return n.delta;
  }
  T operator ()(T const t)       { return update(t); }

  T operator ()() const { return _data.load().value; }
  size_t size()   const { return _data.load().count; }
  T delta()       const { return _data.load().delta; }
  T min()         const { data_t d = _data.load(); return d.count ? d.min : -1; }
  T max()         const { data_t d = _data.load(); return d.count ? d.max : -1; }
private:
  struct data_t {
    T      value;
    T      delta;
    T        min;
    T        max;
    size_t count;
  };
  std::atomic<struct data_t> _data; // thread-safe storage
};

#endif // CUMULATIVE_AVERAGE_HPP__
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */

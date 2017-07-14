//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
//! @file	arrayupdate.h
//! @brief 	Trivial kernel: Updates an array by increasing each value by 42.
//! @authors 	J. Korinth (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __ARRAYUPDATE_H__
#define __ARRAYUPDATE_H__

#define SZ							256
void arrayupdate(int arr[SZ]);

#endif /* __ARRAYUPDATE */

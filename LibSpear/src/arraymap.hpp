#ifndef ARRAYMAP_H
#define ARRAYMAP_H

#include <algorithm>
#include <cassert>
#include <ranges>
#include <span>
#include <stdexcept>
#include <type_traits>

namespace libspear {

/// Flat array pretending to be a map with std::size_t as key_type. Supports few operations of a map
/// and all operations of an std::array with some differences. Differences are in functions size(),
/// begin() and end() -- they count only "non-empty" elements, which mean elements cast to bool
/// being equal to false. To use this container exaclty like std::array, use "all()" member
/// function. Also, as a part of map -- erasing or emptying elements assigns default constructed
/// object to them.
template <typename T, std::size_t N>
class ArrayMap;

namespace arraymap_detail {

template
	< typename T
	, std::size_t N
	, bool enumerated
>
struct Iterator {
	friend ArrayMap<T, N>;
	friend ArrayMap<std::remove_cv_t<T>, N>;

	template <typename TT, std::size_t NN, bool ee>
	friend struct Iterator;

	using difference_type = std::ptrdiff_t;
	using reference = std::conditional_t
		< enumerated
		, std::pair<const std::size_t, T&>
		, T&
	>;
	using pointer = T*;
	using iterator_category = std::forward_iterator_tag;
	using value_type = std::remove_cv_t<T>;

	constexpr Iterator() noexcept = default;
	constexpr Iterator(const Iterator&) noexcept = default;


	template <typename TT, std::size_t NN, bool ee>
	constexpr Iterator(const Iterator<TT, NN, ee>& o) noexcept
	requires(not std::is_same_v<decltype((*this)), decltype((o))>)
		: _element(o._element)
		, _index(o._index)
	{}


	Iterator &operator++() noexcept;
	Iterator operator++(int) noexcept {
		auto it = *this;
		++*this;
		return it;
	}


	constexpr T &dereference() const noexcept {
		return *_element;
	}


	constexpr std::pair<const std::size_t, T&>
	dereference_enumerated() const noexcept {
		return { _index, dereference() };
	}


	constexpr T &operator*() const noexcept
	requires (not enumerated)
	{
		return dereference();
	}


	constexpr auto operator*() const noexcept
	requires (enumerated)
	{
		return dereference_enumerated();
	}


	constexpr T *operator->() const noexcept
	requires (not enumerated)
	{
		return std::addressof(dereference());
	}


	constexpr bool operator==(const Iterator& o) const noexcept {
		return _element == o._element;
	}


	constexpr bool operator!=(const Iterator& o) const noexcept {
		return not (*this == o);
	}


	constexpr auto to_pointer() const noexcept {
		return _element;
	}

protected:
	T *_element {};
	std::size_t _index {};
};

template <typename T, std::size_t N>
using SimpleIterator = Iterator<T, N, false>;

template <typename T, std::size_t N>
using EnumeratedIterator = Iterator<T, N, true>;

}


template <typename T, std::size_t N>
class ArrayMap {
public:
	using mapped_type = T;
	using key_type = std::size_t;
	using value_type = T;
	using iterator = arraymap_detail::SimpleIterator<T, N>;
	using const_iterator = arraymap_detail::SimpleIterator<const T, N>;
	using enumerated_iterator = arraymap_detail::EnumeratedIterator<T, N>;
	using const_enumerated_iterator =
		arraymap_detail::EnumeratedIterator<const T, N>;

	static_assert(
		std::is_same_v<typename std::iterator_traits<iterator>::reference, T&>);
	static_assert(
		std::is_same_v<
			typename std::iterator_traits<const_iterator>::reference,
			const T&>);

	constexpr ArrayMap() = default;
	constexpr ArrayMap(const std::initializer_list<T>&);

	template <std::ranges::range R>
	constexpr ArrayMap(std::from_range_t, R);


	constexpr T &operator[](std::size_t i) noexcept {
		assert(i < N);
		return _content[i];
	}


	constexpr const T &operator[](std::size_t i) const noexcept {
		assert(i < N);
		return _content[i];
	}


	constexpr static bool check_element(const T& element) noexcept {
		return static_cast<bool>(element);
	}


	constexpr bool contains(std::size_t i) const noexcept {
		return i < N and check_element(_content[i]);
	}


	constexpr std::size_t count(std::size_t i) const noexcept {
		return contains(i);
	}


	constexpr T &at(std::size_t i) {
		if (not contains(i))
			throw std::out_of_range("");
		return _content[i];
	}


	constexpr const T &at(std::size_t i) const {
		if (not contains(i))
			throw std::out_of_range("");
		return _content[i];
	}


	constexpr const_iterator find(std::size_t i) const noexcept {
		if (not contains(i))
			return end();
		const_iterator it {};
		it._element = std::addressof(_content[i]);
		it._index = i;
		return it;
	}


	constexpr iterator find(std::size_t i) noexcept {
		if (not contains(i))
			return end();
		iterator it {};
		it._element = std::addressof(_content[i]);
		it._index = i;
		return it;
	}


	constexpr iterator
	begin() noexcept {
		iterator it {};
		it._element = _find_first_nonempty();
		if (it._element)
			it._index = std::distance(std::begin(_content), it._element);
		return it;
	}


	constexpr const_iterator
	begin() const noexcept {
		const_iterator it {};
		it._element = _find_first_nonempty();
		if (it._element)
			it._index = std::distance(std::begin(_content), it._element);
		return it;
	}


	constexpr iterator
	end() noexcept {
		iterator it {};
		it._element = std::end(_content);
		it._index = N;
		return it;
	}


	constexpr const_iterator
	end() const noexcept {
		const_iterator it {};
		it._element = std::end(_content);
		it._index = N;
		return it;
	}


	constexpr std::span<T, N> all() noexcept {
		return _content;
	}


	constexpr std::span<const T, N> all() const noexcept {
		return _content;
	}


	constexpr auto enumerated() noexcept {
		return std::ranges::subrange<enumerated_iterator>(
			enumerated_iterator { begin() },
			enumerated_iterator { end() });
	}


	constexpr auto enumerated() const noexcept {
		return std::ranges::subrange<const_enumerated_iterator>(
			const_enumerated_iterator { begin() },
			const_enumerated_iterator { end() });
	}


	void erase(std::size_t i) {
		if (i >= N)
			return;
		_content[i] = {};
	}


	void erase(iterator it) {
		*it._element = {};
	}


	void clear() {
		for (auto &element : _content) {
			element = {};
		}
	}


	static constexpr std::size_t max_size() noexcept {
		return N;
	}


	static constexpr std::size_t capacity() noexcept {
		return N;
	}


	/// Returns number of NON-EMPTY elements.
	constexpr std::size_t size() const noexcept {
		return std::distance(begin(), end());
	}


	constexpr bool empty() const noexcept {
		return std::ranges::none_of(
			_content,
			[](const T& element) { return check_element(element); });
	}


	std::pair<iterator, bool>
	insert_or_assign(std::size_t index, mapped_type&& element) {
		if (index >= N)
			return { end(), false };
		_content[index] = std::move(element);
		iterator it {};
		it._element = &_content[index];
		it._index = index;
		return { it, true };
	}


	template <class... Args>
	std::pair<iterator, bool>
	emplace(std::size_t index, Args&&... args) {
		if (index >= N)
			return { end(), false };
		_content[index] = T(std::forward<Args>(args)...);
		iterator it {};
		it._element = &_content[index];
		it._index = index;
		return { it, true };
	}


	template <class... Args>
	std::pair<iterator, bool>
	try_emplace(std::size_t index, Args&&... args) {
		if (index >= N)
			return { end(), false };
		iterator it {};
		it._element = &_content[index];
		it._index = index;
		if (check_element(_content[index])) {
			return { it, false };
		}
		_content[index] = T(std::forward<Args>(args)...);
		return { it, true };
	}


	template <class... Args>
	iterator
	try_push_anywhere(Args&&... args) {
		auto it = std::ranges::find_if(
			_content,
			[](const T& element) { return not check_element(element); });
		if (it == std::end(_content))
			return end();
		*it = T(std::forward<Args>(args)...);
		iterator result_it {};
		result_it._element = std::addressof(*it);
		result_it._index = std::distance(std::begin(_content), it);
		return result_it;
	}


	std::pair<std::size_t, T*>
	find_first_empty() noexcept {
		const auto it = std::ranges::find_if(
			_content,
			[](const T& element) { return not check_element(element); });
		return { std::distance(std::begin(_content), it), it };
	}


	std::pair<std::size_t, const T*>
	find_first_empty() const noexcept {
		const auto it = std::ranges::find_if(
			_content,
			[](const T& element) { return not check_element(element); });
		return { std::distance(std::begin(_content), it), it };
	}


private:
	template<typename Self>
	constexpr auto *_find_first_nonempty(this Self& self) noexcept {
		for (auto& element : self._content)
			if (check_element(element))
				return std::addressof(element);
		return std::end(self._content);
	}

private:
	T _content[N] {};
};

namespace arraymap_detail {

template <typename T, std::size_t N, bool enumerated>
inline Iterator<T, N, enumerated>
&Iterator<T, N, enumerated>::operator++() noexcept {
	do {
		++_element;
		++_index;
	} while (_index < N and not ArrayMap<T, N>::check_element(*_element));
	return *this;
}

}

}

#endif // ARRAYMAP_H

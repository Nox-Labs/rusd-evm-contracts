// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.20;

/**
 * NOTE: There is a difference in meaning between "cardinality" and "count":
 *  - cardinality is the physical size of the ring buffer (i.e. max elements).
 *  - count is the number of elements in the buffer, which may be less than cardinality.
 */
library RingBufferLib {
    /**
     * @notice Returns wrapped TWAB index.
     * @dev  In order to navigate the TWAB circular buffer, we need to use the modulo operator.
     * @dev  For example, if `_index` is equal to 32 and the TWAB circular buffer is of `_cardinality` 32,
     *       it will return 0 and will point to the first element of the array.
     * @param _index Index used to navigate through the TWAB circular buffer.
     * @param _cardinality TWAB buffer cardinality.
     * @return TWAB index.
     */
    function wrap(uint256 _index, uint256 _cardinality) internal pure returns (uint256) {
        return _index % _cardinality;
    }

    /**
     * @notice Computes the negative offset from the given index, wrapped by the cardinality.
     * @dev  We add `_cardinality` to `_index` to be able to offset even if `_amount` is superior to `_cardinality`.
     * @param _index The index from which to offset
     * @param _amount The number of indices to offset.  This is subtracted from the given index.
     * @param _count The number of elements in the ring buffer
     * @return Offsetted index.
     */
    function offset(uint256 _index, uint256 _amount, uint256 _count)
        internal
        pure
        returns (uint256)
    {
        return wrap(_index + _count - _amount, _count);
    }

    /// @notice Returns the index of the last recorded TWAB
    /// @param _nextIndex The next available twab index.  This will be recorded to next.
    /// @param _count The count of the TWAB history.
    /// @return The index of the last recorded TWAB
    function newestIndex(uint256 _nextIndex, uint256 _count) internal pure returns (uint256) {
        if (_count == 0) {
            return 0;
        }

        return wrap(_nextIndex + _count - 1, _count);
    }

    function oldestIndex(uint256 _nextIndex, uint256 _count, uint256 _cardinality)
        internal
        pure
        returns (uint256)
    {
        if (_count < _cardinality) {
            return 0;
        } else {
            return wrap(_nextIndex + _cardinality, _cardinality);
        }
    }

    /// @notice Computes the ring buffer index that follows the given one, wrapped by cardinality
    /// @param _index The index to increment
    /// @param _cardinality The number of elements in the Ring Buffer
    /// @return The next index relative to the given index.  Will wrap around to 0 if the next index == cardinality
    function nextIndex(uint256 _index, uint256 _cardinality) internal pure returns (uint256) {
        return wrap(_index + 1, _cardinality);
    }

    /// @notice Computes the ring buffer index that preceeds the given one, wrapped by cardinality
    /// @param _index The index to increment
    /// @param _cardinality The number of elements in the Ring Buffer
    /// @return The prev index relative to the given index.  Will wrap around to the end if the prev index == 0
    function prevIndex(uint256 _index, uint256 _cardinality) internal pure returns (uint256) {
        return _index == 0 ? _cardinality - 1 : _index - 1;
    }
}

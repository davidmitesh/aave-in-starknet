%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.libraries.types.data_types import DataTypes
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_sub,
    uint256_add,
    uint256_eq,
    uint256_check,
    uint256_le,
)
from contracts.libraries.math.wad_ray_math import ray_div, ray_mul, ray, uint256_max
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math_cmp import is_not_zero
from openzeppelin.token.erc20.IERC20 import IERC20
from contracts.interfaces.i_a_token import IAToken
from starkware.starknet.common.syscalls import get_caller_address
#
# Storage var
#

@storage_var
func _reserves(reserve : felt) -> (data : DataTypes.ReserveData):
end

@storage_var
func _reservesList(id : felt) -> (reserve : felt):
end

@storage_var
func _maxStableRateBorrowSizePercent() -> (res : Uint256):
end

@storage_var
func _flashLoanPremiumTotal() -> (res : Uint256):
end

@storage_var
func _flashLoanPremiumToProtocol() -> (res : Uint256):
end

@storage_var
func _reservesCount() -> (res : felt):
end

@event
func withdraw_event(reserve : felt, user : felt, to : felt, amount : Uint256):
end

@event
func supply_event(reserve : felt, user : felt, on_behalf_of : felt, amount : Uint256):
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    _maxStableRateBorrowSizePercent.write(Uint256(2500, 0))
    _flashLoanPremiumTotal.write(Uint256(9, 0))
    _flashLoanPremiumToProtocol.write(Uint256(0, 0))
    return ()
end

#
# Getters
#

@view
func get_reserve_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt
) -> (reserve : DataTypes.ReserveData):
    let (data) = _reserves.read(asset)
    return (data)
end

@view
func get_reserve_address_by_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reserve_id : felt
) -> (address : felt):
    let (reserve_address) = _reservesList.read(reserve_id)
    return (address=reserve_address)
end

@view
func get_reserves_count{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    count : felt
):
    let (count) = _reservesCount.read()
    return (count)
end

@view
func get_reserve_normalized_income{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(asset : felt) -> (res : Uint256):
    let (reserve) = _reserves.read(asset)
    return (reserve.liquidity_index)
end
#
# Externals
#

@external
func init_reserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt, a_token_address : felt
) -> ():
    # check whether asset is valid cairo address contract
    alloc_locals

    with_attr error_message("ZERO_ADDRESS_NOT_ALLOWED"):
        let (is_non_zero_asset) = is_not_zero(asset)
        let (is_non_zero_a_token_address) = is_not_zero(a_token_address)
        # Implementing AND condition
        assert is_non_zero_asset * is_non_zero_a_token_address = 1
    end
    with_attr error_message("UNDERLYING_ASSET_NOT_MATCHED"):
        let (underlying_asset) = IAToken.UNDERLYING_ASSET_ADDRESS(contract_address=a_token_address)
        assert underlying_asset = asset
    end

    let (zeroIndexAddress) = _reservesList.read(0)
    let (current_reserve_count) = _reservesCount.read()
    let (liquidity_index) = ray()
    with_attr error_message("RESERVE_ALREADY_ADDED"):
        # The boolean expression that is implemented below is of form:
        # isReserveNotListed = reserve.id == 0 && reserveList[0] != asset
        let (reserve) = _reserves.read(asset)
        let (first_condition) = is_not_zero(reserve.id)
        assert first_condition = FALSE
        let (second_condition) = is_not_zero(zeroIndexAddress - asset)
        assert second_condition = TRUE
    end

    if zeroIndexAddress == 0:
        let new_reserve_data = DataTypes.ReserveData(0, a_token_address, liquidity_index)
        _reserves.write(asset, new_reserve_data)
        _reservesList.write(0, asset)
        if current_reserve_count == 0:
            _reservesCount.write(current_reserve_count + 1)
        end
        return ()
    else:
        let (emptyIndex) = returnEmptyIndex(1, current_reserve_count)
        if emptyIndex == 0:
            let newReserveData = DataTypes.ReserveData(
                current_reserve_count, a_token_address, liquidity_index
            )
            _reserves.write(asset, newReserveData)
            _reservesList.write(current_reserve_count, asset)
            _reservesCount.write(current_reserve_count + 1)
            return ()
        else:
            let newReserveData = DataTypes.ReserveData(emptyIndex, a_token_address, liquidity_index)
            _reserves.write(asset, newReserveData)
            _reservesList.write(emptyIndex, asset)
            return ()
        end
    end
end

@external
func drop_reserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt
) -> ():
    alloc_locals
    let (reserve) = _reserves.read(asset)
    # logic from ValidationLogic.sol
    with_attr error_message("ZERO_ADDRESS_NOT_VALID"):
        let (isNotZeroAddress) = is_not_zero(asset)
        assert isNotZeroAddress = TRUE
    end

    with_attr error_message("ASSET_NOT_LISTED"):
        # The boolean expression that is implemented below is of form:
        # isReserveListed = reserve.id != 0 || reserveList[0] == asset
        let (is_non_zero_reserve_id) = is_not_zero(reserve.id)
        let (reserve_in_zero_index) = _reservesList.read(0)
        let (is_requested_reserve_in_zero_index_comp) = is_not_zero(asset - reserve_in_zero_index)
        let is_requested_reserve_in_zero_index = 1 - is_requested_reserve_in_zero_index_comp
        # making the OR logic condition
        assert (is_non_zero_reserve_id - 1) * (is_requested_reserve_in_zero_index - 1) = 0
    end

    with_attr error_message("ATOKEN_SUPPLY_NOT_ZERO"):
        let (supply) = IERC20.totalSupply(contract_address=reserve.a_token_address)
        assert supply = Uint256(0, 0)
    end

    # finally deleting the reserve
    _reservesList.write(reserve.id, 0)
    _reserves.write(asset, DataTypes.ReserveData(0, 0, Uint256(0, 0)))
    return ()
end

@external
func supply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt, amount : Uint256, on_behalf_of : felt
) -> ():
    alloc_locals
    # validateSupply logic
    with_attr error_message("ZERO_ADDRESS_NOT_VALID"):
        let (isNotZeroAddress) = is_not_zero(asset)
        assert isNotZeroAddress = TRUE
    end
    with_attr error_message("INVALID_AMOUNT"):
        uint256_check(amount)
        let (is_amount_zero) = uint256_eq(amount, Uint256(0, 0))
        assert is_amount_zero = FALSE
    end

    # transferring asset token to the reserve pool
    let (caller) = get_caller_address()
    let (reserve) = _reserves.read(asset)
    IERC20.transferFrom(
        contract_address=asset, sender=caller, recipient=reserve.a_token_address, amount=amount
    )

    # minting the Atokens to the onBehalfOf
    IAToken.mint(
        contract_address=reserve.a_token_address,
        caller=caller,
        on_behalf_of=on_behalf_of,
        amount=amount,
        index=reserve.liquidity_index,
    )
    supply_event.emit(asset, caller, on_behalf_of, amount)
    return ()
end

@external
func withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt, amount : Uint256, to : felt
) -> (revised_amount : Uint256):
    alloc_locals

    let (reserve) = _reserves.read(asset)
    let (caller) = get_caller_address()
    let (local caller_balance) = IAToken.balanceOf(reserve.a_token_address, caller)

    # validateWithdraw logic
    with_attr error_message("ZERO_ADDRESS_NOT_VALID"):
        let (isNotZeroAddress) = is_not_zero(asset)
        assert isNotZeroAddress = TRUE
    end
    with_attr error_message("INVALID_AMOUNT"):
        uint256_check(amount)
        let (is_amount_zero) = uint256_eq(amount, Uint256(0, 0))
        assert is_amount_zero = FALSE
    end
    with_attr error_message("NOT_ENOUGH_AVAILABLE_USER_BALANCE"):
        let (is_amount_less_than_balance) = uint256_le(amount, caller_balance)
        assert is_amount_less_than_balance = TRUE
    end

    let (max_uint256) = uint256_max()
    let (is_amount_maxed) = uint256_eq(amount, max_uint256)
    tempvar revised_amount : Uint256
    if is_amount_maxed == TRUE:
        assert revised_amount = caller_balance
    else:
        assert revised_amount = amount
    end
    # burning the Atokens and redeeming the underlying asset
    IAToken.burn(
        contract_address=reserve.a_token_address,
        from_=caller,
        receiver_or_underlying=to,
        amount=revised_amount,
        index=reserve.liquidity_index,
    )
    withdraw_event.emit(reserve=asset, user=caller, to=to, amount=revised_amount)
    return (revised_amount)
end

#
# Helper Functions
#

func returnEmptyIndex{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    currentIndex : felt, reservesCount : felt
) -> (result : felt):
    let (address) = _reservesList.read(currentIndex)

    if currentIndex == reservesCount:
        return (0)
    end
    if address == 0:
        return (currentIndex)
    end

    let (next) = returnEmptyIndex(currentIndex + 1, reservesCount)
    return (next)
end

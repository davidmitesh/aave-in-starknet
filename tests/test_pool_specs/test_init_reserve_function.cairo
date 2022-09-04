%lang starknet

from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from contracts.interfaces.i_a_token import IAToken

from contracts.interfaces.i_pool import IPool
from contracts.libraries.math.wad_ray_math import ray
from contracts.libraries.types.data_types import DataTypes
func get_contract_addresses() -> (
    pool : felt,
    asset_1 : felt,
    asset_2 : felt,
    asset_3 : felt,
    a_token_1 : felt,
    a_token_2 : felt,
    a_token_3 : felt,
):
    tempvar pool
    tempvar asset_1
    tempvar asset_2
    tempvar asset_3
    tempvar a_token_1
    tempvar a_token_2
    tempvar a_token_3
    %{ ids.pool = context.pool %}
    %{ ids.asset_1 = context.asset_1 %}
    %{ ids.asset_2 = context.asset_2 %}
    %{ ids.asset_3 = context.asset_3 %}
    %{ ids.a_token_1 = context.a_token_1 %}
    %{ ids.a_token_2 = context.a_token_2 %}
    %{ ids.a_token_3 = context.a_token_3 %}

    return (pool, asset_1, asset_2, asset_3, a_token_1, a_token_2, a_token_3)
end

namespace TestInitReserve:
    # Test 1
    func test_init_reserve_optimistic_flow{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }():
        alloc_locals
        let (
            local pool,
            local asset_1,
            local asset_2,
            local asset_3,
            local a_token_1,
            local a_token_2,
            local a_token_3,
        ) = get_contract_addresses()

        # This gets passed as it's a valid init reserve
        IPool.init_reserve(pool, asset_1, a_token_1)

        # checking the reserve_count after first init
        let (count) = IPool.get_reserves_count(pool)
        assert count = 1

        # checking the reserve data of the first reserve
        let (first_reserve_data : DataTypes.ReserveData) = IPool.get_reserve_data(pool, asset_1)
        let (liquidity_index) = ray()
        assert first_reserve_data.id = 0
        assert first_reserve_data.a_token_address = a_token_1
        assert first_reserve_data.liquidity_index = liquidity_index

        # should init new reserve if valid data provided and show correct count after
        IPool.init_reserve(pool, asset_2, a_token_2)
        let (reserve_data : DataTypes.ReserveData) = IPool.get_reserve_data(pool, asset_2)
        let (liquidity_index) = ray()
        assert reserve_data.id = 1
        assert reserve_data.a_token_address = a_token_2
        assert reserve_data.liquidity_index = liquidity_index
        let (second_count) = IPool.get_reserves_count(pool)
        assert second_count = 2

        # Dropping first reserve with asset_1 and trying to again init with asset_2 which should revert
        IPool.drop_reserve(pool, asset_1)

        # Initializing new reserve with asset_3 and it should take the empty spot of dropped reserve
        # count should remain same as empty spot is replaced.
        IPool.init_reserve(pool, asset_3, a_token_3)
        let (reserve_data : DataTypes.ReserveData) = IPool.get_reserve_data(pool, asset_3)
        assert reserve_data.id = 0
        assert reserve_data.a_token_address = a_token_3
        assert reserve_data.liquidity_index = liquidity_index
        let (revised_count) = IPool.get_reserves_count(pool)
        assert revised_count = 2
        let (reserve_address) = IPool.get_reserve_address_by_id(pool, 0)
        assert reserve_address = asset_3

        return ()
    end

    # Test 2
    func test_init_reserve_fails_when_passed_unmatched_asset_token{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }():
        alloc_locals
        let (
            local pool,
            local asset_1,
            local asset_2,
            local asset_3,
            local a_token_1,
            local a_token_2,
            local a_token_3,
        ) = get_contract_addresses()

        IPool.init_reserve(pool, asset_1, a_token_1)
        IPool.init_reserve(pool, asset_2, a_token_2)
        # should revert if reserve is initialized with random asset and aToken
        %{ expect_revert(error_message = "UNDERLYING_ASSET_NOT_MATCHED") %}
        IPool.init_reserve(pool, 111, a_token_3)
        return ()
    end

    # Test 3
    func test_init_reserve_fails_when_passed_zero_addresses{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }():
        alloc_locals
        let (
            local pool,
            local asset_1,
            local asset_2,
            local asset_3,
            local a_token_1,
            local a_token_2,
            local a_token_3,
        ) = get_contract_addresses()

        IPool.init_reserve(pool, asset_1, a_token_1)
        IPool.init_reserve(pool, asset_2, a_token_2)
        # should revert if tried to initialize with zero address
        %{ expect_revert(error_message="ZERO_ADDRESS_NOT_ALLOWED") %}
        IPool.init_reserve(pool, 0, 0)
        return ()
    end

    # Test 4
    func test_init_reserve_fails_when_reserve_with_same_asset_initialized{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }():
        alloc_locals
        let (
            local pool,
            local asset_1,
            local asset_2,
            local asset_3,
            local a_token_1,
            local a_token_2,
            local a_token_3,
        ) = get_contract_addresses()

        IPool.init_reserve(pool, asset_1, a_token_1)
        IPool.init_reserve(pool, asset_2, a_token_2)
        # should revert if the reserve with same asset and aToken is tried to initialize
        %{ expect_revert(error_message = "RESERVE_ALREADY_ADDED") %}
        IPool.init_reserve(pool, asset_1, a_token_1)
        return ()
    end
end

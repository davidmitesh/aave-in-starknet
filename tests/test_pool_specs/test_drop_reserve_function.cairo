%lang starknet

from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from contracts.interfaces.i_a_token import IAToken
from openzeppelin.token.erc20.IERC20 import IERC20
from contracts.interfaces.i_pool import IPool
from contracts.libraries.math.wad_ray_math import ray
from contracts.libraries.types.data_types import DataTypes
from starkware.starknet.common.syscalls import get_caller_address
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

namespace TestDropReserve:
    # Test 1
    func test_drop_reserve_optimistic_flow{
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
        IPool.init_reserve(pool, asset_2, a_token_2)
        IPool.init_reserve(pool, asset_3, a_token_3)

        # checking the reserve_count after 3 inits
        let (count) = IPool.get_reserves_count(pool)
        assert count = 3

        # checking the reserve data of the third reserve
        let (reserve_data : DataTypes.ReserveData) = IPool.get_reserve_data(pool, asset_3)
        let (liquidity_index) = ray()
        assert reserve_data.id = 2
        assert reserve_data.a_token_address = a_token_3
        assert reserve_data.liquidity_index = liquidity_index

        # Dropping second reserve with asset_2
        IPool.drop_reserve(pool, asset_2)

        # checking the reserve data of the second reserve to see if the reserve is dropped
        let (reserve_data : DataTypes.ReserveData) = IPool.get_reserve_data(pool, asset_2)
        assert reserve_data.id = 0
        assert reserve_data.a_token_address = 0
        assert reserve_data.liquidity_index = Uint256(0, 0)
        let (reserve_address) = IPool.get_reserve_address_by_id(pool, 1)
        assert reserve_address = 0

        return ()
    end

    # Test 2
    func test_drop_reserve_fails_when_tried_to_drop_reserve_with_non_zero_supply{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }():
        alloc_locals
        local PRANK_USER_1
        local pool
        local asset_1
        local a_token_1
        %{
            ids.PRANK_USER_1 =  context.PRANK_USER_1
            ids.pool = context.pool
            ids.asset_1 = context.asset_1
            ids.a_token_1 = context.a_token_1
            stop_prank_callable_asset = start_prank(context.PRANK_USER_1,target_contract_address = ids.asset_1)
        %}
        IPool.init_reserve(pool, asset_1, a_token_1)
        %{
            #checking asset_1's balance of the PRANK_USER_1
            balance = load(ids.asset_1,"ERC20_balances","Uint256",key = [ids.PRANK_USER_1])
            assert balance == [100,0]
        %}

        # approving pool to spend on behalf of PRANK_USER_1
        IERC20.approve(asset_1, pool, Uint256(10 ** 26, 0))

        %{ stop_prank_callable_asset() %}

        %{ stop_prank_callable_pool = start_prank(context.PRANK_USER_1,target_contract_address = ids.pool) %}
        # Supplying asset_1 to pool from PRANK_USER_1's balance
        IPool.supply(pool, asset_1, Uint256(100, 0), PRANK_USER_1)
        %{ stop_prank_callable_pool() %}

        # Checking the a_tokens corresponsing to asset_1 of user PRANK_USER_1
        let (balance) = IAToken.balanceOf(a_token_1, PRANK_USER_1)
        assert balance = Uint256(100, 0)

        # Should revert if tried to drop reserve when total Supply not empty
        %{ expect_revert(error_message = "ATOKEN_SUPPLY_NOT_ZERO") %}
        IPool.drop_reserve(pool, asset_1)

        return ()
    end

    # Test 3
    func test_drop_reserve_fails_when_passed_zero_address{
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
        # should revert if tried to drop reserve with zero address
        %{ expect_revert(error_message="ZERO_ADDRESS_NOT_VALID") %}
        IPool.drop_reserve(pool, 0)
        return ()
    end

    # Test 4
    func test_drop_reserve_fails_when_tried_to_drop_unlisted_asset{
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
        # should revert if the reserve with the asset not listed is tried to drop
        %{ expect_revert(error_message = "ASSET_NOT_LISTED") %}
        IPool.drop_reserve(pool, asset_3)
        return ()
    end
end

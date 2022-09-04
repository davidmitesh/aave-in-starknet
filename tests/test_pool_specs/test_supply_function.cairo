%lang starknet

from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from contracts.interfaces.i_a_token import IAToken
from openzeppelin.token.erc20.IERC20 import IERC20
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

namespace TestSupply:
    # Test 1
    func test_supply_optimistic_flow{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }():
        alloc_locals
        tempvar PRANK_USER_1
        tempvar pool
        tempvar asset_1
        tempvar a_token_1
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
        IERC20.approve(asset_1, pool, Uint256(100, 0))

        %{ stop_prank_callable_asset() %}

        %{ stop_prank_callable_pool = start_prank(context.PRANK_USER_1,target_contract_address = ids.pool) %}
        # Supplying asset_1 to pool from PRANK_USER_1's balance

        # expecting an event after the supply is triggered
        %{ expect_events({"name": "supply_event", "data": [ids.asset_1,ids.PRANK_USER_1,ids.PRANK_USER_1,100,0]}) %}
        IPool.supply(pool, asset_1, Uint256(100, 0), PRANK_USER_1)
        %{ stop_prank_callable_pool() %}

        # Checking the a_tokens corresponsing to asset_1 of user PRANK_USER_1
        let (balance) = IAToken.balanceOf(a_token_1, PRANK_USER_1)
        assert balance = Uint256(100, 0)

        return ()
    end

    # Test 2
    func test_supply_fails_when_passed_zero_address{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }():
        alloc_locals
        tempvar PRANK_USER_1
        tempvar pool
        tempvar asset_1
        tempvar a_token_1
        %{
            ids.PRANK_USER_1 =  context.PRANK_USER_1
            ids.pool = context.pool
            ids.asset_1 = context.asset_1
            ids.a_token_1 = context.a_token_1
        %}

        IPool.init_reserve(pool, asset_1, a_token_1)
        # should revert if tried to initialize with zero address
        %{ expect_revert(error_message="ZERO_ADDRESS_NOT_VALID") %}
        IPool.supply(pool, 0, Uint256(100, 0), PRANK_USER_1)
        return ()
    end
end

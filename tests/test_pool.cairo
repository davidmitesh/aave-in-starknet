%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from tests.test_pool_specs.test_init_reserve_function import TestInitReserve
from tests.test_pool_specs.test_drop_reserve_function import TestDropReserve
from tests.test_pool_specs.test_supply_function import TestSupply
from tests.test_pool_specs.test_withdraw_function import TestWithdraw
const PRANK_USER_1 = 111
const PRANK_USER_2 = 222
const PRANK_USER_3 = 333
# For assets
const TOKEN_1_NAME = 'ETHEREUM'
const TOKEN_2_NAME = 'MATIC'
const TOKEN_3_NAME = 'CELO'
const SYMBOL_1 = 'ETH'
const SYMBOL_2 = 'MATIC'
const SYMBOL_3 = 'CELO'
# For aTokens corresponding to the assets
const ATOKEN_1_NAME = 'AETHEREUM'
const ATOKEN_2_NAME = 'AMATIC'
const ATOKEN_3_NAME = 'ACELO'
const ASYMBOL_1 = 'AETH'
const ASYMBOL_2 = 'AMATIC'
const ASYMBOL_3 = 'ACELO'

const DECIMALS = 18
const INITIAL_SUPPLY_LOW = 100
const INITIAL_SUPPLY_HIGH = 0

@external
func __setup__{syscall_ptr : felt*, range_check_ptr}():
    %{
        context.pool = deploy_contract("./contracts/protocol/pool.cairo", []).contract_address

        # Deploying 3 different assets (n three different ERC20 Tokens)
        context.asset_1 = deploy_contract("./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", [ids.TOKEN_1_NAME, ids.SYMBOL_1, ids.DECIMALS, ids.INITIAL_SUPPLY_LOW, ids.INITIAL_SUPPLY_HIGH, ids.PRANK_USER_1]).contract_address
        context.asset_2 = deploy_contract("./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", [ids.TOKEN_2_NAME, ids.SYMBOL_2, ids.DECIMALS, ids.INITIAL_SUPPLY_LOW, ids.INITIAL_SUPPLY_HIGH, ids.PRANK_USER_2]).contract_address
        context.asset_3 = deploy_contract("./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", [ids.TOKEN_3_NAME, ids.SYMBOL_3, ids.DECIMALS, ids.INITIAL_SUPPLY_LOW, ids.INITIAL_SUPPLY_HIGH, ids.PRANK_USER_3]).contract_address

        # Deploying the a_token corresponding to 3 different assets
        context.a_token_1 = deploy_contract("./contracts/protocol/a_token.cairo", [context.pool, context.asset_1, ids.DECIMALS, ids.ATOKEN_1_NAME, ids.ASYMBOL_1]).contract_address
        context.a_token_2 = deploy_contract("./contracts/protocol/a_token.cairo", [context.pool, context.asset_2, ids.DECIMALS, ids.ATOKEN_2_NAME, ids.ASYMBOL_2]).contract_address
        context.a_token_3 = deploy_contract("./contracts/protocol/a_token.cairo", [context.pool, context.asset_3, ids.DECIMALS, ids.ATOKEN_3_NAME, ids.ASYMBOL_3]).contract_address

        context.PRANK_USER_1 = ids.PRANK_USER_1
    %}

    return ()
end

#
# Tests for init_reserve() function
#

@external
func test_init_reserve_optimistic_flow{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    TestInitReserve.test_init_reserve_optimistic_flow()
    return ()
end

@external
func test_init_reserve_fails_when_passed_unmatched_asset_token{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    TestInitReserve.test_init_reserve_fails_when_passed_unmatched_asset_token()
    return ()
end

@external
func test_init_reserve_fails_when_passed_zero_addresses{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    TestInitReserve.test_init_reserve_fails_when_passed_zero_addresses()
    return ()
end

@external
func test_init_reserve_fails_when_reserve_with_same_asset_initialized{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    TestInitReserve.test_init_reserve_fails_when_reserve_with_same_asset_initialized()
    return ()
end

#
# Tests for drop_reserve() function
#

@external
func test_drop_reserve_optimistic_flow{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    TestDropReserve.test_drop_reserve_optimistic_flow()
    return ()
end

@external
func test_drop_reserve_fails_when_tried_to_drop_reserve_with_non_zero_supply{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    TestDropReserve.test_drop_reserve_fails_when_tried_to_drop_reserve_with_non_zero_supply()
    return ()
end

@external
func test_drop_reserve_fails_when_passed_zero_address{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    TestDropReserve.test_drop_reserve_fails_when_passed_zero_address()
    return ()
end

@external
func test_drop_reserve_fails_when_tried_to_drop_unlisted_asset{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    TestDropReserve.test_drop_reserve_fails_when_tried_to_drop_unlisted_asset()
    return ()
end

#
# Tests for supply() function
#

@external
func test_supply_optimistic_flow{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ):
    TestSupply.test_supply_optimistic_flow()
    return ()
end

@external
func test_supply_fails_when_passed_zero_address{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    TestSupply.test_supply_fails_when_passed_zero_address()
    return ()
end

#
# Tests for withdraw() function
#

@external
func test_withdraw_optimistic_flow{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    TestWithdraw.test_withdraw_optimistic_flow()
    return ()
end

@external
func test_withdraw_fails_when_not_enough_balance_to_withdraw{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    TestWithdraw.test_withdraw_fails_when_not_enough_balance_to_withdraw()
    return ()
end

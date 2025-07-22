// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Constants {
    // File constants
    string constant Underscore = "_";
    string constant Dash = "-";
    string constant Slash = "/";
    string StrategyImplementationPrefix = string.concat("StrategyImplementation", Underscore);
    string VaultPrefix = string.concat("Vault", Underscore);
    string StrategyPrefix = string.concat("Strategy", Underscore);
    string BridgeAdapterPrefix = string.concat("Periphery_BridgeAdapter", Underscore);
    string SwapRouterPrefix = string.concat("Periphery_SwapRouter", Underscore);

    // Colors for console logs
    string constant BLUE = "\u001b[34m";
    string constant GREEN = "\u001b[32m";
    string constant RED = "\u001b[31m";
    string constant YELLOW = "\u001b[33m";
    string constant MAGENTA = "\u001b[35m";
    string constant CYAN = "\u001b[36m";
    string constant WHITE = "\u001b[37m";
    string constant BLACK = "\u001b[30m";
    string constant RESET = "\u001b[0m";
}

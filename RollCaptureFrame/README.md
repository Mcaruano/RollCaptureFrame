# How to invoke
Simply opening your bank with this AddOn enabled will generate the report. The character's inventory as well as their bank (and all bank bags) will be parsed.

# Output
After your bank and bags have been parsed, you MUST either logout/exit/Alt+F4 OR /reload for the final report to be saved to the file system. These are the only lifecycle events that cause the transactions to be logged to the output file. The output file will be located at: `WTF\Account\<your_account>\Whitemane\<character_name>\SavedVariables\TnTCharacterBankSnapshotter.lua`

# Format
The contents of the inventory report file will look like this:
```lua
BankContents = {
	"Tntconsumes,128768,5", -- [1]
	"Tntconsumes,118630,20", -- [2]
	"Tntconsumes,124444,2", -- [3]
	"Tntconsumes,3865,3", -- [4]
	"Tntconsumes,159788,1", -- [5]
	"Tntconsumes,127844,3", -- [6]
	"Tntconsumes,3866,2", -- [7]
	"Tntconsumes,21215,39", -- [8]
	"Tntconsumes,103789,3", -- [9]
	"Tntconsumes,3864,3", -- [10]
	"Tntconsumes,127846,24", -- [11]
	"Tntconsumes,44601,15", -- [12]
	"Tntconsumes,116424,12", -- [13]
	"Tntconsumes,153154,3", -- [14]
	"Tntconsumes,0,300342", -- [15]
}
```
The format of each record is: **characterName,itemID,quantity**. The last record represents the amount of Copper the bank has - we use an ItemID of "0" to indicate this to the back-end.

# What do I do with this file?
The purpose of this file (and therefore this AddOn) is to simply allow us a way to "audit" our Bank Transactions which are collected via our TnTBankTransactionMonitor AddOn. There are a number of complex edge-cases that can arise when parsing the mailbox, and so this AddOn helps us ensure the integrity of our bank inventory. One important call-out is that the Bank report this AddOn generates is character-specific, whereas the TnTBankTransactionMonitor logs transactions across both Tntbank as well as Tntbanktwo.
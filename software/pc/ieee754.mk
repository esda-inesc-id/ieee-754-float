# Includes
INCLUDE+=-I$(SW_DIR)
INCLUDE+=-I$(SW_DIR)/pc

$(SW_DIR)/pc/ieee754.a:
	make -C $(SW_DIR)/pc SW_DIR=$(SW_DIR)/.. ieee754.a

clean-ieee754:
	make -C $(SW_DIR)/pc SW_DIR=$(SW_DIR)/.. clean

.PHONY: clean-ieee754

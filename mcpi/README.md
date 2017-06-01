# MCPI - Mega65 Command Processor Interface

An ugly attempt to create a stand alone (ie, working even without any C65 ROM)
command line interface for Mega65 with commands and utilities to maintain
Mega-65 specific functions (ie: SD-card, network download, etc).

Currently it's in very early stage. Everything is implemented by my own,
even keyboard scanning and all the SD-card access routines (and yes, all of
them are VERY ugly and buggy!). However currently it still needs to be loaded
from C65 mode. In the future it will include a CP/M implementation as
well, with software-level 8080 (or maybe Z80) emulation, and FCB level
access to the SD-card directly (no CP/M specific file system is needed).

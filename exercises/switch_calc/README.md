# Switch Calculator

## Introduction

The objective of this exercise is to demonstrate how one can run
almost the exact same P4 program on both NetFPGA and bmv2 in Mininet.

I say "almost" because the P4->NetFPGA externs are not currently
support in bmv2. So we can't use the `const_reg_rw` extern function
in our P4 program. If you take a look at the switch_calc starter code
you will see that the extern function call is wrapper in the following
pre-processor directives, which remove the contained code when
compiling to bmv2.

```
#ifndef BMV2
 <code to remove>
#endif
```

At this point, you should have already implemented the switch_calc
P4 program and compiled it onto the NetFPGA platform. This exercise
will walk you through the steps to test your program in bmv2-Mininet.

## Testing your switch_calc solution

1. Make sure that you have cloned your P4-NetFPGA repo into this VM and
   your environment variables are set correctly. The `P4_PROJECT_DIR`
   environment variable should be pointing to the switch_calc directory
   in your P4-NetFPGA repository.

2. In your shell, run:
   ```bash
   make
   ```
   This will:
   * compile your `switch_calc.p4`
   * start a Mininet instance with one switch (`s1`) and one host (`h1`)

2. You should now see a Mininet command prompt. Open a terminal on `h1`:
   ```bash
   mininet> xterm h1
   ```
3. In the xterm window, navigate to `$P4_PROJECT_DIR/sw/hw_test_tool`
   ```bash
   # cd $P4_PROJECT_DIR/sw/hw_test_tool
   ```

4. Open up the `switch_calc_tester.py` script and update the following line:
   ```
   -IFACE = "eth1"
   +IFACE = "eth0"
   ```
   By default, Mininet hosts are created with an `eth0` interface.

5. Run the test script and test the switch:
   ```bash
   # ./switch_calc_tester.py

   testing> run_test 1 + 1
   ``` 

6. Type `exit` to leave everything.
   Then, to stop mininet:
   ```bash
   make stop
   ```
   And to delete all pcaps, build files, and logs:
   ```bash
   make clean
   ```

### A note about the control plane

The `s1-commands.txt` file in this directory contains the bmv2
commands to populate initial table entries upon building the
topology. Note that these commands are slightly different than
those in the `commands.txt` file used by P4->NetFPGA.


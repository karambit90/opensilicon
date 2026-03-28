import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


# REFERENCE MODEL (Golden Vector)

class EMGProcessorModel:
    def __init__(self, threshold=6, duration_limit=3):
        self.threshold = threshold
        self.duration_limit = duration_limit
        self.duration_counter = 0
        self.event_counter = 0
        self.valid_pulse = 0

    def reset(self):
        self.duration_counter = 0
        self.event_counter = 0
        self.valid_pulse = 0

    def process_sample(self, emg_value):
        # Threshold detection
        above_threshold = emg_value > self.threshold

        # Temporal validation
        if above_threshold:
            self.duration_counter += 1
        else:
            self.duration_counter = 0

        valid_event = self.duration_counter >= self.duration_limit

        # FSM simulation
        if valid_event and not self.valid_pulse:
            self.valid_pulse = 1
            self.event_counter += 1
        else:
            self.valid_pulse = 0

# TEST SUITE
@cocotb.test()
async def test_emg_processor_golden_vectors(dut):
    dut._log.info("Starting Golden Vector EMG Processor Test")

    # Clock setup
    clock = Clock(dut.clk, 10, unit="us")  # 10us period
    cocotb.start_soon(clock.start())

    # Initialize DUT
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Initialize software reference model
    model = EMGProcessorModel(threshold=6, duration_limit=3)
    model.reset()

   
    # TEST 1: Noise (should NOT trigger, nonononono bad manners)
  
    dut._log.info("TEST 1: Noise")
    for t in range(5):
        noise = t % 5  # 0-4: below threshold
        dut.ui_in.value = noise
        await RisingEdge(dut.clk)
        model.process_sample(noise)

        expected_pulse = model.valid_pulse
        actual_pulse = int(dut.uo_out.value & 0x1)
        assert actual_pulse == expected_pulse, f"Noise test failed at t={t}"

    # TEST 2: Short spike (should NOT trigger, nonononon again bad manners)
   
    dut._log.info("TEST 2: Short spike")
    dut.ui_in.value = 10  # above threshold
    await ClockCycles(dut.clk, 1)
    model.process_sample(10)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2)
    model.process_sample(0)

    expected_pulse = model.valid_pulse
    actual_pulse = int(dut.uo_out.value & 0x1)
    assert actual_pulse == expected_pulse, "Short spike incorrectly triggered"

   
    # TEST 3: Valid contraction (should trigger, yes good boy)

    dut._log.info("TEST 3: Valid contraction")
    for t in range(5):
        dut.ui_in.value = 10  # sustained above threshold
        await RisingEdge(dut.clk)
        model.process_sample(10)

        expected_pulse = model.valid_pulse
        actual_pulse = int(dut.uo_out.value & 0x1)
        assert actual_pulse == expected_pulse, f"Valid contraction failed at t={t}"

    
    # TEST 4: Repeated contractions, now it is fun
 
    dut._log.info("TEST 4: Repeated contractions")
    for rep in range(3):
        # Sustained high
        for t in range(4):
            dut.ui_in.value = 10
            await RisingEdge(dut.clk)
            model.process_sample(10)

            expected_pulse = model.valid_pulse
            actual_pulse = int(dut.uo_out.value & 0x1)
            assert actual_pulse == expected_pulse, f"Rep {rep} failed at t={t}"

        # Low signal between contractions
        for t in range(2):
            dut.ui_in.value = 0
            await RisingEdge(dut.clk)
            model.process_sample(0)

            expected_pulse = model.valid_pulse
            actual_pulse = int(dut.uo_out.value & 0x1)
            assert actual_pulse == expected_pulse, f"Rep {rep} low phase failed at t={t}"

    dut._log.info("All Golden Vector tests passed for EMG processor")

from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(10);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");
    # s.loadTopo("example.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.ROUTING_CHANNEL);
    # s.addChannel(s.FLOODING_CHANNEL);

    # Needs some time to build routing tables
    s.runTime(500);

    for x in range(1, 6):
        s.routeDMP(x);
        s.runTime(1);

    s.LSPing(1, 3);
    s.runTime(10);

if __name__ == '__main__':
    main()

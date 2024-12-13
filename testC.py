from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    # s.loadTopo("tuna-melt.topo");
    s.loadTopo("example.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    # s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.TRANSPORT_CHANNEL);

    # After sending a ping, simulate a little to prevent collision.

    s.runTime(300);
    s.serverStart(1, 41);
    s.runTime(60);
    s.serverStart(1, 41);
    s.runTime(60);
    s.serverStart(1, 41);
    s.runTime(60);

    s.clientStart(4, 1, 3, 41);   
    s.runTime(60);

    s.clientStart(3, 1, 3, 41);
    s.runTime(60);

    s.clientStart(2, 1, 3, 41);   
    s.runTime(60);

    s.broadcast(4, "test");
    s.runTime(60);
    s.getList(4);
    s.runTime(60);
    s.unicast(4, 3, "test 2");
    s.runTime(1000);



if __name__ == '__main__':
    main()

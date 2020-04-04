/************************************************************************/
/*																		*/
/*	video_demo.c	--	Nexys Video HDMI demonstration 						*/
/*																		*/
/************************************************************************/
/*	Author: Sam Bobrowicz												*/
/*	Copyright 2015, Digilent Inc.										*/
/************************************************************************/
/*  Module Description: 												*/
/*																		*/
/*		This file contains code for running a demonstration of the		*/
/*		Video input and output capabilities on the Nexys Video. It is a good	*/
/*		example of how to properly use the display_ctrl and				*/
/*		video_capture drivers.											*/
/*																		*/
/*																		*/
/************************************************************************/
/*  Revision History:													*/
/* 																		*/
/*		11/25/2015(SamB): Created										*/
/*		03/31/2017(ArtVVB): Updated sleep functions for 2016.4			*/
/*																		*/
/************************************************************************/

/* ------------------------------------------------------------ */
/*				Include File Definitions						*/
/* ------------------------------------------------------------ */

#include "PmodOLEDrgb.h"
#include "video_demo.h"
#include "video_capture/video_capture.h"
#include "display_ctrl/display_ctrl.h"
#include "intc/intc.h"
#include <stdio.h>
#include "xuartlite_l.h"
//#include "xuartps.h"
#include "math.h"
#include <ctype.h>
#include <stdlib.h>
#include "xil_types.h"
#include "xil_cache.h"
#include "xparameters.h"
#include "sleep.h"
//#include <unistd.h>
//Standard library includes

#include <string.h>

//BSP includes for peripherals

#include "netif/xadapter.h"

#include "platform.h"
#include "platform_config.h"
#if defined (__arm__) || defined(__aarch64__)
#include "xil_printf.h"
#endif

//LWIP include files
#include "lwip/ip_addr.h"
#include "lwip/tcp.h"
#include "lwip/err.h"
#include "lwip/tcp.h"
#include "lwip/inet.h"
#if LWIP_IPV6==1
#include "lwip/ip.h"
#else
#if LWIP_DHCP==1
#include "lwip/dhcp.h"
#endif
#endif


void lwip_init(); /* missing declaration in lwIP */

//TCP Network Params
#define SRC_MAC_ADDR {0x00, 0x0a, 0x35, 0x00, 0x01, 0x02}
#define SRC_IP4_ADDR "192.168.1.10"
#define IP4_NETMASK "255.255.255.0"
#define IP4_GATEWAY "192.168.1.1"
#define SRC_PORT 22

#define DEST_IP4_ADDR  "192.168.1.11"
#define DEST_IP6_ADDR "fe80::6600:6aff:fe71:fde6"
#define DEST_PORT 9090

#define TCP_SEND_BUFSIZE 20

/*
 * XPAR redefines
 */
#define DYNCLK_BASEADDR XPAR_AXI_DYNCLK_0_BASEADDR
#define VGA_VDMA_ID XPAR_AXIVDMA_0_DEVICE_ID
#define DISP_VTC_ID XPAR_VTC_0_DEVICE_ID
//#define VID_VTC_ID XPAR_VTC_1_DEVICE_ID
#define VID_GPIO_ID XPAR_AXI_GPIO_VIDEO_DEVICE_ID
//#define VID_VTC_IRPT_ID XPAR_INTC_0_VTC_1_VEC_ID
#define VID_GPIO_IRPT_ID XPAR_INTC_0_GPIO_0_VEC_ID
#define SCU_TIMER_ID XPAR_AXI_TIMER_0_DEVICE_ID
#define UART_BASEADDR XPAR_UARTLITE_0_BASEADDR
#define CUST_ADDR 0x44A30000


//Function prototypes
#if LWIP_IPV6==1
void print_ip6(char *msg, ip_addr_t *ip);
#else
void print_ip(char *msg, ip_addr_t *ip);
void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw);
#endif
int setup_client_conn(struct tcp_pcb **g_pcb);
void tcp_fasttmr(void);
void tcp_slowtmr(void);

//Function prototypes for callbacks
static err_t tcp_client_connected(void *arg, struct tcp_pcb *tpcb, err_t err);
static err_t tcp_client_recv(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err);
static err_t tcp_client_sent(void *arg, struct tcp_pcb *tpcb, u16_t len);
static void tcp_client_err(void *arg, err_t err);
static void tcp_client_close(struct tcp_pcb *pcb);


void PrintMenu();

//DHCP global variables
#if LWIP_IPV6==0
#if LWIP_DHCP==1
extern volatile int dhcp_timoutcntr;
err_t dhcp_start(struct netif *netif);
#endif
#endif



////Networking global variables
extern volatile int TcpFastTmrFlag;
extern volatile int TcpSlowTmrFlag;
//static struct netif server_netif;
//struct netif *app_netif;
static struct tcp_pcb *c_pcb;
//char is_connected;



/* ------------------------------------------------------------ */
/*				Global Variables								*/
/* ------------------------------------------------------------ */

/*
 * Display and Video Driver structs
 */
DisplayCtrl dispCtrl;
XAxiVdma vdma;
VideoCapture videoCapt;
INTC intc;
char fRefresh; //flag used to trigger a refresh of the Menu on video detect

/*
 * Framebuffers for video data
 */
u8 frameBuf[DISPLAY_NUM_FRAMES][DEMO_MAX_FRAME];
u8 *pFrames[DISPLAY_NUM_FRAMES]; //array of pointers to the frame buffers

/*
 * Interrupt vector table
 */
const ivt_t ivt[] = {
	videoGpioIvt(VID_GPIO_IRPT_ID, &videoCapt),
	//videoVtcIvt(VID_VTC_IRPT_ID, &(videoCapt.vtc))
};

/* ------------------------------------------------------------ */
/*				Procedure Definitions							*/
/* ------------------------------------------------------------ */

int main(void)
{
	PmodOLEDrgb oledrgb;
	Xil_ICacheEnable();
	Xil_DCacheEnable();
	DemoInitialize();
	OLEDrgb_begin(&oledrgb, XPAR_PMODOLEDRGB_0_AXI_LITE_GPIO_BASEADDR,
	         XPAR_PMODOLEDRGB_0_AXI_LITE_SPI_BASEADDR);
	static struct netif server_netif;
	struct netif *app_netif;
	//static struct tcp_pcb *c_pcb;
	//char is_connected;
	//Varibales for IP parameters
#if LWIP_IPV6==0
	ip_addr_t ipaddr, netmask, gw;
#endif

	//The mac address of the board. this should be unique per board
	unsigned char mac_ethernet_address[] = SRC_MAC_ADDR;

	//Network interface
	app_netif = &server_netif;

	//Initialize platform
	init_platform();

	//Defualt IP parameter values
#if LWIP_IPV6==0
#if LWIP_DHCP==1
    ipaddr.addr = 0;
	gw.addr = 0;
	netmask.addr = 0;
#else
	(void)inet_aton(SRC_IP4_ADDR, &ipaddr);
	(void)inet_aton(IP4_NETMASK, &netmask);
	(void)inet_aton(IP4_GATEWAY, &gw);
#endif
#endif

	//LWIP initialization
	lwip_init();

	//Setup Network interface and add to netif_list
#if (LWIP_IPV6 == 0)
	if (!xemac_add(app_netif, &ipaddr, &netmask,
						&gw, mac_ethernet_address,
						PLATFORM_EMAC_BASEADDR)) {
		xil_printf("Error adding N/W interface\n");
		return -1;
	}
#else
	if (!xemac_add(app_netif, NULL, NULL, NULL, mac_ethernet_address,
						PLATFORM_EMAC_BASEADDR)) {
		xil_printf("Error adding N/W interface\n");
		return -1;
	}
	app_netif->ip6_autoconfig_enabled = 1;

	netif_create_ip6_linklocal_address(app_netif, 1);
	netif_ip6_addr_set_state(app_netif, 0, IP6_ADDR_VALID);

#endif
	netif_set_default(app_netif);

	//Now enable interrupts
	platform_enable_interrupts();

	//Specify that the network is up
	netif_set_up(app_netif);

#if (LWIP_IPV6 == 0)
#if (LWIP_DHCP==1)
	/* Create a new DHCP client for this interface.
	 * Note: you must call dhcp_fine_tmr() and dhcp_coarse_tmr() at
	 * the predefined regular intervals after starting the client.
	 */
	dhcp_start(app_netif);
	dhcp_timoutcntr = 24;

	while(((app_netif->ip_addr.addr) == 0) && (dhcp_timoutcntr > 0))
		xemacif_input(app_netif);

	if (dhcp_timoutcntr <= 0) {
		if ((app_netif->ip_addr.addr) == 0) {
			xil_printf("DHCP Timeout\n");
			xil_printf("Configuring default IP of %s\n", SRC_IP4_ADDR);
			(void)inet_aton(SRC_IP4_ADDR, &(app_netif->ip_addr));
			(void)inet_aton(IP4_NETMASK, &(app_netif->netmask));
			(void)inet_aton(IP4_GATEWAY, &(app_netif->gw));
		}
	}

	ipaddr.addr = app_netif->ip_addr.addr;
	gw.addr = app_netif->gw.addr;
	netmask.addr = app_netif->netmask.addr;
#endif
#endif

	//Print connection settings
#if (LWIP_IPV6 == 0)
	print_ip_settings(&ipaddr, &netmask, &gw);
#else
	print_ip6("Board IPv6 address ", &app_netif->ip6_addr[0].u_addr.ip6);
#endif

	struct tcp_pcb *g_pcb;
	g_pcb = NULL;

	//Setup connection
	//setup_client_conn(&g_pcb);
	u32 RegValue;
	RegValue = XAxiVdma_ReadReg(0x44A00000,
		              0x00000028);
	//xil_printf("DEBUG: origin RegValue = 0x%08x\r\n", RegValue);
	volatile unsigned int* cust_ip = (unsigned int*) CUST_ADDR;
	*(cust_ip + 3) = 0x08301010;
	PrintMenu();
	char userInput = 0;

	/* Flush UART FIFO */
	while (!XUartLite_IsReceiveEmpty(UART_BASEADDR))
	{
		XUartLite_ReadReg(UART_BASEADDR, XUL_RX_FIFO_OFFSET);
	}

	fRefresh = 0;

	/* Wait for data on UART */
	while (XUartLite_IsReceiveEmpty(UART_BASEADDR) && !fRefresh)
	{}

	/* Store the first character in the UART receive FIFO and echo it */
	if (!XUartLite_IsReceiveEmpty(UART_BASEADDR))
	{
		userInput = XUartLite_ReadReg(UART_BASEADDR, XUL_RX_FIFO_OFFSET);
		xil_printf("%c", userInput);
	}
	else  //Refresh triggered by video detect interrupt
	{
		userInput = 'r';
	}

	switch (userInput)
	{
	case '1':
		*(cust_ip + 1) = 0x00000002;
		break;
	case '2':
		*(cust_ip + 1) = 0x00000003;
		break;
	default :
		xil_printf("\n\rInvalid Selection");
		usleep(50000);
	}

//	while(1){
//		//xil_printf("DEBUG: Light = 0x%08x\r\n", *((unsigned char*)(cust_ip+1)));
//		double fval = ((double)*(cust_ip) / (double)100000);
//		int whole, thousandths;
//		whole = fval;
//		thousandths = (fval - whole) * 1000;
//		xil_printf("DEBUG: Delay = %d.%03dms\r\n", whole, thousandths);
//		sleep(2);
//	}
	//Event loop
	char oled_result[8];
	while (1) {
		//Call tcp_tmr functions
		//Must be called regularly
		if (TcpFastTmrFlag) {
			tcp_fasttmr();
			TcpFastTmrFlag = 0;
		}
		if (TcpSlowTmrFlag) {
			tcp_slowtmr();
			TcpSlowTmrFlag = 0;
		}

		//Process data queued after interupt
		xemacif_input(app_netif);
		u8_t apiflags = TCP_WRITE_FLAG_COPY | TCP_WRITE_FLAG_MORE;
		char send_buf[8] = "DATA";
		u32_t send_data = 0;
		send_data = *(cust_ip);

		double fval = ((double)(send_data) / (double)100000);
		int whole, thousandths;
		whole = fval;
		thousandths = (fval - whole) * 1000;

		sprintf(oled_result, "%d.%d ms", whole, thousandths);
		OLEDrgb_Clear(&oledrgb);
		OLEDrgb_SetCursor(&oledrgb, 0, (oledrgb.ychOledrgbMax) /2);
		OLEDrgb_PutString(&oledrgb, oled_result);
		*((u32_t*)&send_buf + 1) = send_data;
		//Loop until enough room in buffer (should be right away)
		while (tcp_sndbuf(g_pcb) < 8);
		err_t err;
		//Enqueue some data to send
		err = tcp_write(g_pcb, send_buf, 8, apiflags);
		if (err != ERR_OK) {
			xil_printf("TCP client: Error on tcp_write: %d\n", err);
			return err;
		}

		//send the data packet
		err = tcp_output(g_pcb);
		if (err != ERR_OK) {
			xil_printf("TCP client: Error on tcp_output: %d\n",err);
			return err;
		}
	}
while(1){
	xil_printf("DEBUG: Light = 0x%08x\r\n", *((unsigned char*)cust_ip));
	double fval = ((double)*(cust_ip+2) / (double)100000);
	int whole, thousandths;
	whole = fval;
	thousandths = (fval - whole) * 1000;
	xil_printf("DEBUG: Delay = %d.%03dms\r\n", whole, thousandths);
	sleep(1);
}
	return 0;
}


void DemoInitialize()
{
	int Status;
	XAxiVdma_Config *vdmaConfig;
	int i;

	/*
	 * Initialize an array of pointers to the 3 frame buffers
	 */
	for (i = 0; i < DISPLAY_NUM_FRAMES; i++)
	{
		pFrames[i] = frameBuf[i];
	}

	/*
	 * Initialize VDMA driver
	 */
	vdmaConfig = XAxiVdma_LookupConfig(VGA_VDMA_ID);
	if (!vdmaConfig)
	{
		xil_printf("No video DMA found for ID %d\r\n", VGA_VDMA_ID);
		return;
	}
	Status = XAxiVdma_CfgInitialize(&vdma, vdmaConfig, vdmaConfig->BaseAddress);
	if (Status != XST_SUCCESS)
	{
		xil_printf("VDMA Configuration Initialization failed %d\r\n", Status);
		return;
	}

	/*
	 * Initialize the Display controller and start it
	 */
	Status = DisplayInitialize(&dispCtrl, &vdma, DISP_VTC_ID, DYNCLK_BASEADDR, pFrames, DEMO_STRIDE);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Display Ctrl initialization failed during demo initialization%d\r\n", Status);
		return;
	}
	DisplaySetMode(&dispCtrl, &VMODE_1920x1080);
	Status = DisplayStart(&dispCtrl);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Couldn't start display during demo initialization%d\r\n", Status);
		return;
	}

	/*
	 * Initialize the Interrupt controller and start it.
	 */
	Status = fnInitInterruptController(&intc);
	if(Status != XST_SUCCESS) {
		xil_printf("Error initializing interrupts");
		return;
	}
	fnEnableInterrupts(&intc, &ivt[0], sizeof(ivt)/sizeof(ivt[0]));

	// /*
	//  * Initialize the Video Capture device
	//  */
	// Status = VideoInitialize(&videoCapt, &intc, &vdma, VID_GPIO_ID, VID_VTC_ID, VID_VTC_IRPT_ID, pFrames, DEMO_STRIDE, DEMO_START_ON_DET);
	// if (Status != XST_SUCCESS)
	// {
	// 	xil_printf("Video Ctrl initialization failed during demo initialization%d\r\n", Status);
	// 	return;
	// }

	/*
	 * Set the Video Detect callback to trigger the menu to reset, displaying the new detected resolution
	 */
	//VideoSetCallback(&videoCapt, DemoISR, &fRefresh);

	DemoPrintTest(dispCtrl.framePtr[0], dispCtrl.vMode.width, dispCtrl.vMode.height, dispCtrl.stride, DEMO_PATTERN_0);
	DemoPrintTest(dispCtrl.framePtr[1], dispCtrl.vMode.width, dispCtrl.vMode.height, dispCtrl.stride, DEMO_PATTERN_1);
	xil_printf("INIT DONE\n");
	return;
}

void DemoPrintTest(u8 *frame, u32 width, u32 height, u32 stride, int pattern)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	switch (pattern)
	{
	case DEMO_PATTERN_0:
		for(xcoi = 0; xcoi < (width*3); xcoi+=3)
		{
			/*
			 * Convert color intensities to integers < 256, and trim values >=256
			 */
			iPixelAddr = xcoi;
			for(ycoi = 0; ycoi < height; ycoi++)
			{
				frame[iPixelAddr] = 255;
				frame[iPixelAddr + 1] = 255;
				frame[iPixelAddr + 2] = 255;
				/*
				 * This pattern is printed one vertical line at a time, so the address must be incremented
				 * by the stride instead of just 1.
				 */
				iPixelAddr += stride;
			}
		}
		/*
		 * Flush the framebuffer memory range to ensure changes are written to the
		 * actual memory, and therefore accessible by the VDMA.
		 */
		Xil_DCacheFlushRange((unsigned int) frame, DEMO_MAX_FRAME);
		break;
	case DEMO_PATTERN_1:
		for(xcoi = 0; xcoi < (width*3); xcoi+=3)
		{
			iPixelAddr = xcoi;
			for(ycoi = 0; ycoi < height; ycoi++)
			{
				frame[iPixelAddr] = 0;
				frame[iPixelAddr + 1] = 0;
				frame[iPixelAddr + 2] = 0;
				/*
				 * This pattern is printed one vertical line at a time, so the address must be incremented
				 * by the stride instead of just 1.
				 */
				iPixelAddr += stride;
			}
		}
		/*
		 * Flush the framebuffer memory range to ensure changes are written to the
		 * actual memory, and therefore accessible by the VDMA.
		 */
		Xil_DCacheFlushRange((unsigned int) frame, DEMO_MAX_FRAME);
		break;
	default :
		xil_printf("Error: invalid pattern passed to DemoPrintTest");
	}
}
//
//void DemoISR(void *callBackRef, void *pVideo)
//{
//	char *data = (char *) callBackRef;
//	*data = 1; //set fRefresh to 1
//}



#if LWIP_IPV6==1
void print_ip6(char *msg, ip_addr_t *ip)
{
	print(msg);
	xil_printf(" %x:%x:%x:%x:%x:%x:%x:%x\n",
			IP6_ADDR_BLOCK1(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK2(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK3(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK4(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK5(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK6(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK7(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK8(&ip->u_addr.ip6));

}
#else
void print_ip(char *msg, ip_addr_t *ip)
{
	print(msg);
	xil_printf("%d.%d.%d.%d\n", ip4_addr1(ip), ip4_addr2(ip),
			ip4_addr3(ip), ip4_addr4(ip));
}

void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
{

	print_ip("Board IP: ", ip);
	print_ip("Netmask : ", mask);
	print_ip("Gateway : ", gw);
}
#endif


int setup_client_conn(struct tcp_pcb **g_pcb)
{
	struct tcp_pcb *pcb;
	err_t err;
	ip_addr_t remote_addr;

	xil_printf("Setting up client connection\n");

#if LWIP_IPV6==1
	remote_addr.type = IPADDR_TYPE_V6;
	err = inet6_aton(DEST_IP6_ADDR, &remote_addr);
#else
	err = inet_aton(DEST_IP4_ADDR, &remote_addr);
#endif

	if (!err) {
		xil_printf("Invalid Server IP address: %d\n", err);
		return -1;
	}

	//Create new TCP PCB structure
	pcb = tcp_new_ip_type(IPADDR_TYPE_ANY);
	if (!pcb) {
		xil_printf("Error creating PCB. Out of Memory\n");
		return -1;
	}

	//Bind to specified @port
	err = tcp_bind(pcb, IP_ANY_TYPE, SRC_PORT);
	if (err != ERR_OK) {
		xil_printf("Unable to bind to port %d: err = %d\n", SRC_PORT, err);
		return -2;
	}

	//Connect to remote server (with callback on connection established)
	*g_pcb = pcb;
	err = tcp_connect(pcb, &remote_addr, DEST_PORT, tcp_client_connected);
	if (err) {
		xil_printf("Error on tcp_connect: %d\n", err);
		tcp_client_close(pcb);
		return -1;
	}

	//is_connected = 0;

	xil_printf("Waiting for server to accept connection\n");

	return 0;
}

static void tcp_client_close(struct tcp_pcb *pcb)
{
	err_t err;

	xil_printf("Closing Client Connection\n");

	if (pcb != NULL) {
		tcp_sent(pcb, NULL);
		tcp_recv(pcb,NULL);
		tcp_err(pcb, NULL);
		err = tcp_close(pcb);
		if (err != ERR_OK) {
			/* Free memory with abort */
			tcp_abort(pcb);
		}
	}
}

static err_t tcp_client_connected(void *arg, struct tcp_pcb *tpcb, err_t err)
{
	if (err != ERR_OK) {
		tcp_client_close(tpcb);
		xil_printf("Connection error\n");
		return err;
	}

	xil_printf("Connection to server established\n");

	//Store state (for callbacks)
	c_pcb = tpcb;
	//is_connected = 1;

	//Set callback values & functions
	tcp_arg(c_pcb, NULL);
	tcp_recv(c_pcb, tcp_client_recv);
	tcp_sent(c_pcb, tcp_client_sent);
	tcp_err(c_pcb, tcp_client_err);

	//ADD CODE HERE to do when connection established
	//END OF ADDED CODE

	return ERR_OK;
}

static err_t tcp_client_recv(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err)
{
	//If no data, connection closed
	if (!p) {
		xil_printf("No data received\n");
		tcp_client_close(tpcb);
		return ERR_OK;
	}



	//ADD CODE HERE to do on packet reception

	//Print message
	xil_printf("Packet received, %d bytes\n", p->tot_len);

	//Print packet contents to terminal
	char* packet_data = (char*) malloc(p->tot_len);
	pbuf_copy_partial(p, packet_data, p->tot_len, 0); //Note - inefficient way to access packet data
	u32_t i;

//	u32_t num = *(u32_t*)packet_data;
//	*(sev_seg) = ((num>>24)&0xff) | // move byte 3 to byte 0
//            ((num<<8)&0xff0000) | // move byte 1 to byte 2
//            ((num>>8)&0xff00) | // move byte 2 to byte 1
//            ((num<<24)&0xff000000); // byte 0 to byte 3

	for(i = 0; i < p->tot_len; i = i + 1)
		putchar(packet_data[i]);

	//END OF ADDED CODE



	//Indicate done processing
	tcp_recved(tpcb, p->tot_len);

	//Free the received pbuf
	pbuf_free(p);

	return 0;
}

static err_t tcp_client_sent(void *arg, struct tcp_pcb *tpcb, u16_t len)
{


	//ADD CODE HERE to do on packet acknowledged

	//Print message
	xil_printf("Packet sent successfully, %d bytes\n", len);

	//END OF ADDED CODE



	return 0;
}

static void tcp_client_err(void *arg, err_t err)
{
	LWIP_UNUSED_ARG(err);
	tcp_client_close(c_pcb);
	c_pcb = NULL;
	xil_printf("TCP connection aborted\n");
}

void PrintMenu()
{
	xil_printf("\x1B[H"); //Set cursor to top left of terminal
	xil_printf("\x1B[2J"); //Clear terminal
	xil_printf("*******************************************************************\n\r");
	xil_printf("*             Display Input Lag/Response Time Tester              *\n\r");
	xil_printf("*******************************************************************\n\r");
	xil_printf("*Display Resolution: %28s*\n\r", dispCtrl.vMode.label);
	printf("*Display Pixel Clock Freq. (MHz): %15.3f*\n\r", dispCtrl.pxlFreq);
	xil_printf("*Display Frame Index: %27d*\n\r", dispCtrl.curFrame);
	//if (videoCapt.state == VIDEO_DISCONNECTED) xil_printf("*Video Capture Resolution: %22s*\n\r", "!HDMI UNPLUGGED!");
	xil_printf("*Video Frame Index: %29d*\n\r", videoCapt.curFrame);
	xil_printf("**************************************************\n\r");
	xil_printf("\n\r");
	xil_printf("1 - Input Lag Test\n\r");
	xil_printf("2 - Response Time\n\r");
	xil_printf("\n\r");
	xil_printf("\n\r");
	xil_printf("Enter a selection:");
}

